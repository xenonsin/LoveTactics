-- Tests for models/relic.lua: the run-scoped relic registry, inventory, weighted drop pool, overworld
-- dispatcher and combat-integration queries. Driven headlessly with synthetic party members and, where a
-- hook's exact math matters, a synthetic relic def injected into Relic.defs. Pure logic over Player
-- helpers + the passed ctx, so no window or love.graphics is needed.

local Relic = require("models.relic")

-- A stand-in party member with resource pools as { current, max } tables (mirrors overworld_ability_spec).
local function char(id, hp, mana, stam)
    return {
        id = id, name = id,
        stats = {
            health = hp and { current = hp[1], max = hp[2] } or nil,
            mana = mana and { current = mana[1], max = mana[2] } or nil,
            stamina = stam and { current = stam[1], max = stam[2] } or nil,
        },
    }
end

local function gridStub()
    return {
        objective = { x = 5, y = 5 },
        pathNeighbors = function() return { true, true } end, -- degree 2 (not a dead-end)
        reveal = function(self, x, y, r) self.revealedAt = { x = x, y = y, r = r } end,
    }
end

local function ctxFor(party, extra)
    local c = { player = { party = party, gold = 100 }, party = party, grid = gridStub(), state = Relic.newState() }
    if extra then for k, v in pairs(extra) do c[k] = v end end
    return c
end

return {
    {
        name = "the registry loads the relic data files with the expected shape",
        fn = function()
            local coin = Relic.get("relic_pilgrims_coin")
            assert(coin and coin.name == "Pilgrim's Coin", "Pilgrim's Coin should load from data/relics")
            assert(coin.alignment == "virtue" and coin.affinity == "overworld", "its axes should be set")
            local vice = Relic.get("relic_gluttons_purse")
            assert(vice and vice.alignment == "vice" and vice.cost, "a Vice should carry an alignment and a cost line")
        end,
    },
    {
        name = "grant adds to the run, is unique per run, and held reads back in order",
        fn = function()
            local s = Relic.newState()
            assert(Relic.grant(s, "relic_pilgrims_coin"), "a first grant returns the def")
            assert(Relic.grant(s, "relic_alms_bowl"), "a second, different relic grants")
            assert(not Relic.grant(s, "relic_pilgrims_coin"), "a duplicate grant is a no-op (relics are unique per run)")
            assert(not Relic.grant(s, "relic_not_a_real_id"), "an unknown id grants nothing")
            assert(Relic.has(s, "relic_alms_bowl"), "has() sees a held relic")
            local held = Relic.held(s)
            assert(#held == 2 and held[1].id == "relic_pilgrims_coin" and held[2].id == "relic_alms_bowl",
                "held returns the relics in the order taken")
        end,
    },
    {
        name = "the drop pool filters by alignment, affinity and what the run already holds",
        fn = function()
            local vices = Relic.pool({ alignment = "vice" })
            assert(#vices > 0, "there should be Vices to draw")
            for _, e in ipairs(vices) do assert(e.def.alignment == "vice", "a vice-only pool yields only Vices") end
            -- exclude a held relic and it drops out of the pool (no duplicate drops).
            local all = Relic.pool({})
            local excl = Relic.pool({ exclude = { "relic_pilgrims_coin" } })
            assert(#excl == #all - 1, "excluding a held relic removes exactly it from the pool")
            for _, e in ipairs(excl) do assert(e.id ~= "relic_pilgrims_coin", "the excluded relic is gone") end
        end,
    },
    {
        name = "roll draws an id from the pool by weight (a single-entry pool is deterministic)",
        fn = function()
            local one = Relic.roll({ { id = "relic_martyrs_bell", weight = 1 } })
            assert(one == "relic_martyrs_bell", "a one-relic pool always rolls that relic")
            assert(Relic.roll({}) == nil, "an empty pool rolls nil")
        end,
    },
    {
        name = "slate draws distinct relics and leans one Vice against the Virtues",
        fn = function()
            for _ = 1, 40 do -- the composition is randomised; assert it over many draws, not one
                local ids = Relic.slate({}, 3)
                assert(#ids == 3, "a healthy shelf fills all three slots")
                local seen, vices = {}, 0
                for _, id in ipairs(ids) do
                    assert(not seen[id], "a slate never repeats a relic")
                    seen[id] = true
                    if Relic.get(id).alignment == "vice" then vices = vices + 1 end
                end
                assert(vices == 1, "exactly one card is the temptation, the rest are Virtues")
            end
        end,
    },
    {
        name = "slate honours exclude and degrades gracefully on a thin shelf",
        fn = function()
            -- Everything the run already holds is off the slate.
            local held = { "relic_pilgrims_coin", "relic_alms_bowl" }
            for _ = 1, 20 do
                for _, id in ipairs(Relic.slate({ exclude = held }, 3)) do
                    assert(id ~= "relic_pilgrims_coin" and id ~= "relic_alms_bowl",
                        "an excluded relic never appears on the slate")
                end
            end
            -- Thin shelf: pin the pool to two relics and the slate returns two, not three, and never pads
            -- with a duplicate. A shelf of one still answers with that one; an empty one answers empty.
            local all = {}
            for id in pairs(Relic.defs) do all[#all + 1] = id end
            local function excludeAllBut(keep)
                local ex = {}
                for _, id in ipairs(all) do
                    local wanted = false
                    for _, k in ipairs(keep) do if k == id then wanted = true end end
                    if not wanted then ex[#ex + 1] = id end
                end
                return ex
            end
            local two = Relic.slate({ exclude = excludeAllBut({ "relic_pilgrims_coin", "relic_gluttons_purse" }) }, 3)
            assert(#two == 2, "a two-relic shelf yields a two-card slate")
            assert(two[1] ~= two[2], "a short slate is short, never padded with a duplicate")
            assert(#Relic.slate({ exclude = excludeAllBut({ "relic_alms_bowl" }) }, 3) == 1,
                "a one-relic shelf yields a one-card slate")
            assert(#Relic.slate({ exclude = all }, 3) == 0, "an exhausted shelf yields an empty slate")
        end,
    },
    {
        name = "slate falls back to Virtues when the vice shelf is spent",
        fn = function()
            local vices = {}
            for id, def in pairs(Relic.defs) do
                if def.alignment == "vice" then vices[#vices + 1] = id end
            end
            local ids = Relic.slate({ exclude = vices }, 3)
            assert(#ids == 3, "with every Vice held the slate still fills from the Virtue shelf")
            for _, id in ipairs(ids) do
                assert(Relic.get(id).alignment == "virtue", "the Vice guarantee is a preference, not a contract")
            end
        end,
    },
    {
        name = "dispatch fires only held relics' hooks, namespaces scratch by id, and notifies",
        fn = function()
            local a = char("ally_a", { 60, 60 })
            local ctx = ctxFor({ a }, { cell = { x = 2, y = 3, encounter = { kind = "combat" } } })
            Relic.grant(ctx.state, "relic_pilgrims_coin")
            local seen = {}
            ctx.notify = function(m) seen[#seen + 1] = m end
            Relic.dispatch("encounterCleared", ctx)
            assert(ctx.player.gold == 108, "Pilgrim's Coin should add 8g on a win (100 -> 108)")
            assert(ctx.state.scratch["relic_pilgrims_coin"], "the relic's scratch should be namespaced by id")
            assert(#seen == 1 and seen[1]:match("Pilgrim"), "a firing relic pushes a toast")
            -- a relic NOT held never fires.
            local ctx2 = ctxFor({ a })
            Relic.dispatch("encounterCleared", ctx2)
            assert(ctx2.player.gold == 100, "an un-held relic must not pay")
        end,
    },
    {
        name = "a synthetic relic proves per-run scratch accumulates and banked reads it",
        fn = function()
            Relic.defs["relic_test_counter"] = {
                name = "Test Counter", alignment = "virtue", affinity = "overworld",
                encounterCleared = function(_, bucket) bucket.n = (bucket.n or 0) + 1 end,
                banked = function(bucket) return bucket.n end,
            }
            local ctx = ctxFor({ char("ally", { 20, 20 }) })
            Relic.grant(ctx.state, "relic_test_counter")
            Relic.dispatch("encounterCleared", ctx)
            Relic.dispatch("encounterCleared", ctx)
            local bucket = ctx.state.scratch["relic_test_counter"]
            assert(bucket.n == 2, "two dispatches accumulate in the run scratch")
            assert(Relic.bankedCount("relic_test_counter", bucket) == 2, "bankedCount reads the def's banked()")
            Relic.defs["relic_test_counter"] = nil -- leave the registry as we found it
        end,
    },
    {
        name = "a battleStart relic queues opening boons through grantBoon",
        fn = function()
            local a, b = char("ally_a", { 40, 40 }), char("ally_b", { 40, 40 })
            local ctx = ctxFor({ a, b })
            Relic.grant(ctx.state, "relic_duelists_spur")
            local out = Relic.dispatch("battleStart", ctx)
            local boons = Relic.openingBoons(out)
            -- No formation is set on the stub, so frontRow() falls back to the whole party.
            assert(#boons == 2, "Duelist's Spur should queue a boon for each front-row unit")
            for _, boon in ipairs(boons) do assert(boon.id == "status_hasted", "the boon is Hasted") end
        end,
    },
    {
        name = "a Vice's drain wounds but never fells -- it floors at 1",
        fn = function()
            local low = char("ally_low", { 2, 40 }) -- 2 HP: a 3-point bite must not drop below 1
            local ctx = ctxFor({ low }, { cell = { x = 1, y = 1, encounter = { kind = "combat" } }, spoils = { gold = 0 } })
            Relic.grant(ctx.state, "relic_cursed_lucre")
            Relic.dispatch("encounterCleared", ctx)
            assert(low.stats.health.current == 1, "Cursed Lucre's toll floors at 1, never fells (2 -> 1)")
            assert(ctx.player.gold == 112, "and it still pays its 12g (100 -> 112)")
        end,
    },
    {
        name = "grantedTraits collects each combat relic's trait ids with its scope, for battle setup",
        fn = function()
            local s = Relic.newState()
            Relic.grant(s, "relic_martyrs_bell")
            Relic.grant(s, "relic_pilgrims_coin") -- a pure-overworld relic contributes no trait
            local traits = Relic.grantedTraits(s)
            assert(#traits == 1, "only the combat relic grants a trait")
            assert(traits[1].trait == "trait_second_wind" and traits[1].scope == "party",
                "Martyr's Bell grants trait_second_wind to the whole party")
        end,
    },
    {
        name = "combatTraitsByChar resolves each combat relic to the members that wear it",
        fn = function()
            local a, b = char("ally_a", { 40, 40 }), char("ally_b", { 40, 40 })
            local s = Relic.newState()
            Relic.grant(s, "relic_martyrs_bell") -- party scope
            Relic.grant(s, "relic_pilgrims_coin") -- overworld only, grants no trait
            -- No formation on these stubs, so a "party"-scope relic reaches everyone.
            local byChar = Relic.combatTraitsByChar(s, { party = { a, b } }, { a, b })
            assert(byChar[a] and byChar[a][1] == "trait_second_wind", "ally A wears Martyr's Bell's trait")
            assert(byChar[b] and byChar[b][1] == "trait_second_wind", "ally B wears it too (party scope)")
            for _, ids in pairs(byChar) do assert(#ids == 1, "the overworld relic contributes no trait") end
        end,
    },
    {
        name = "Trait.attach folds a unit's relicTraits in with the character's own",
        fn = function()
            local Trait = require("models.trait")
            -- A bare unit whose char carries no traits and no grid: the only trait it should end with is
            -- the one its run relic granted, proving the attach path reads unit.relicTraits.
            local unit = { char = { id = "ally", traits = {}, inventory = {} }, relicTraits = { "trait_second_wind" } }
            Trait.attach(unit)
            assert(Trait.has(unit, "trait_second_wind"), "a relic-granted trait attaches like an innate one")
        end,
    },
    {
        name = "step relics mark a tile once, so pacing mints nothing",
        fn = function()
            local ctx = ctxFor({ char("ally", { 40, 40 }) })
            Relic.grant(ctx.state, "relic_poachers_map")
            local cell = { x = 3, y = 3 }
            ctx.cell = cell
            Relic.dispatch("step", ctx)
            assert(cell.mapped, "a stepped tile is marked mapped")
            -- Re-walking the same cell must not re-mark or re-pay: cell.mapped short-circuits the hook.
            local goldAfterFirst = ctx.player.gold
            for _ = 1, 20 do Relic.dispatch("step", ctx) end
            assert(ctx.player.gold == goldAfterFirst, "a mapped tile never pays again (no pacing exploit)")
        end,
    },
}
