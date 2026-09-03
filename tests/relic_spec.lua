-- Tests for models/relic.lua: the run-scoped relic registry, the STACKING inventory, the rarity-weighted
-- drop pool, the flat-stat bags, the rare tier's rules and the overworld dispatcher. Driven headlessly
-- with synthetic party members and, where a hook's exact math matters, a synthetic relic def injected
-- into Relic.defs. Pure logic over Player helpers + the passed ctx, so no window is needed.
--
-- WHAT THIS FILE STOPPED TESTING, since a spec that quietly loses cases is worse than one that never had
-- them. Gone with the moral axis: the alignment filter, the "one Vice against two Virtues" slate
-- composition, the vice-shelf fallback, and the `guaranteed` last-resort draw with its BARE_SHELF_GOLD
-- consolation. None of those are behaviours any more -- there is one shelf, the slate is a plain rarity
-- roll, and a pool that stacks can never be exhausted. The Poacher's Map fog-gate cases went with the
-- relic itself.

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
        pathNeighbors = function() return { true, true } end,
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
            local tithe = Relic.get("relic_whetstone_tithe")
            assert(tithe and tithe.name == "Whetstone Tithe", "Whetstone Tithe should load from data/relics")
            assert(tithe.tier == "common" and tithe.bonus.damage == 1, "a common is a flat stat on the bag")
            local purse = Relic.get("relic_gluttons_purse")
            assert(purse and purse.cost, "a relic with a downside carries a cost line")
        end,
    },
    {
        -- ONE SHELF. The axis is deleted, and the check is that it stays deleted: a blueprint that grows
        -- an `alignment` or an `affinity` back is a blueprint reintroducing a taxonomy nothing reads.
        name = "no relic carries the deleted alignment or affinity axes",
        fn = function()
            for id, def in pairs(Relic.defs) do
                assert(def.alignment == nil, id .. " still carries an alignment")
                assert(def.affinity == nil, id .. " still carries an affinity")
                assert(def.tier == nil or Relic.TIER_WEIGHT[def.tier], id .. " has an unknown tier: " .. tostring(def.tier))
            end
        end,
    },
    {
        -- The shelf is authored to a shape (18/10/8) and the ladder only means anything if the rungs stay
        -- roughly that. A rung that drifts to two entries stops being a rung.
        name = "the shelf is stocked across all three rungs",
        fn = function()
            local n = { common = 0, uncommon = 0, rare = 0 }
            for _, def in pairs(Relic.defs) do
                n[def.tier or "common"] = (n[def.tier or "common"] or 0) + 1
            end
            assert(n.common >= 12, "the common rung is the bulk of the shelf; found " .. n.common)
            assert(n.uncommon >= 6, "the uncommon rung needs stock; found " .. n.uncommon)
            assert(n.rare >= 6, "the rare rung needs stock; found " .. n.rare)
        end,
    },
    {
        name = "magnitude ladders as base + (n-1) * step, and step defaults to base",
        fn = function()
            assert(Relic.magnitude(0, 3, 2) == 0, "a relic not held contributes nothing")
            assert(Relic.magnitude(1, 3, 2) == 3, "one copy is the base")
            assert(Relic.magnitude(2, 3, 2) == 5, "a second copy adds the step")
            assert(Relic.magnitude(4, 3, 2) == 9, "and it keeps climbing")
            assert(Relic.magnitude(3, 5) == 15, "an absent step defaults to the base (plain linear)")
        end,
    },
    {
        -- THE HEADLINE REVERSAL. A duplicate used to be a no-op; it is now the whole point.
        name = "grant stacks a duplicate instead of refusing it",
        fn = function()
            local s = Relic.newState()
            local def, n = Relic.grant(s, "relic_whetstone_tithe")
            assert(def and n == 1, "a first grant returns the def and a count of one")
            local _, n2 = Relic.grant(s, "relic_whetstone_tithe")
            assert(n2 == 2, "a duplicate grant deepens rather than refusing")
            assert(Relic.count(s, "relic_whetstone_tithe") == 2, "count reads the stack back")
            assert(not Relic.grant(s, "relic_not_a_real_id"), "an unknown id still grants nothing")
            Relic.grant(s, "relic_weight_of_plate")
            local held = Relic.held(s)
            assert(#held == 2, "held lists DISTINCT relics, not copies")
            assert(held[1].id == "relic_whetstone_tithe" and held[1].count == 2, "and carries each one's count")
            assert(held[2].id == "relic_weight_of_plate", "in the order first taken")
        end,
    },
    {
        name = "the flat-stat bag aggregates every held relic at its own stack depth",
        fn = function()
            local s = Relic.newState()
            Relic.grant(s, "relic_whetstone_tithe")  -- +1 damage
            Relic.grant(s, "relic_whetstone_tithe")  -- +1 more
            Relic.grant(s, "relic_weight_of_plate")  -- +1 defense
            local bonus = Relic.statBonus(s)
            assert(bonus.damage == 2, "two Whetstone Tithes are +2 damage; got " .. tostring(bonus.damage))
            assert(bonus.defense == 1, "and the single plate is +1 defense")
            -- maxBonus is its own bag, because it feeds a different fold (Combat.unreservedMax).
            Relic.grant(s, "relic_full_skin")
            assert(Relic.maxBonus(s).health == 6, "maxBonus relics land in the maxBonus bag, not the stat one")
            assert(Relic.statBonus(s).health == nil, "and never in the flat one")
        end,
    },
    {
        -- An uncommon is a TRADE: both halves are in the same bag and both ladder.
        name = "an uncommon's gain and its price both stack",
        fn = function()
            local s = Relic.newState()
            Relic.grant(s, "relic_keen_edge")
            local one = Relic.statBonus(s)
            assert(one.damage == 3 and one.defense == -3, "one Keen Edge is +3/-3")
            Relic.grant(s, "relic_keen_edge")
            local two = Relic.statBonus(s)
            assert(two.damage == 5 and two.defense == -5, "a second adds the step to BOTH halves; got "
                .. two.damage .. "/" .. two.defense)
        end,
    },
    {
        -- The Braced Stance is the deliberate asymmetry: its price is paid once, so a second copy cannot
        -- root the company. If this ever fails, movement has been made accidentally deletable.
        name = "a price authored at step 0 is paid exactly once",
        fn = function()
            local s = Relic.newState()
            for _ = 1, 4 do Relic.grant(s, "relic_braced_stance") end
            local b = Relic.statBonus(s)
            assert(b.movement == -1, "four Braced Stances still cost exactly one movement; got " .. tostring(b.movement))
            assert(b.defense == 13, "while the armour keeps climbing (4 + 3 + 3 + 3); got " .. tostring(b.defense))
        end,
    },
    {
        name = "the breakdown names each relic and its count, and sums to the bag",
        fn = function()
            local s = Relic.newState()
            Relic.grant(s, "relic_whetstone_tithe")
            Relic.grant(s, "relic_whetstone_tithe")
            Relic.grant(s, "relic_keen_edge")
            local rows, total = Relic.bonusBreakdown(s, "damage"), 0
            assert(#rows == 2, "one row per relic that moves the stat")
            for _, r in ipairs(rows) do total = total + r.value end
            assert(total == Relic.statBonus(s).damage, "the rows sum to the aggregate the fold uses")
            local named = false
            for _, r in ipairs(rows) do if r.label:match("x2") then named = true end end
            assert(named, "a stacked relic names its count, so a +2 row is not read against a +1 card")
            assert(Relic.bonusParts(s).damage, "bonusParts keys the same rows by stat for battle setup")
        end,
    },
    {
        -- THE RULE/MAGNITUDE SPLIT. A rare's inversion fires once however deep it is stacked.
        name = "a rare's rule fires once while its magnitude ladders",
        fn = function()
            local s = Relic.newState()
            Relic.grant(s, "relic_rooted_oath")
            Relic.grant(s, "relic_rooted_oath")
            Relic.grant(s, "relic_rooted_oath")
            local rules = Relic.rules(s)
            assert(rules.noMove, "the inversion is present")
            assert(rules.noMove.count == 3, "and reports how deep it is stacked, for the magnitude")
            local scale = Relic.get("relic_rooted_oath").ruleScale.abilityRange
            assert(Relic.magnitude(rules.noMove.count, scale[1], scale[2]) == 7,
                "three copies pay +7 range (3 + 2 + 2) for the one rooting")
        end,
    },
    {
        -- PRECEDENCE. Three rares reach for the health pool and a run can hold all of them; the order
        -- they resolve in is a spec line, not an accident of `pairs`.
        name = "health-pool rules resolve in the declared order, last one legible",
        fn = function()
            local s = Relic.newState()
            Relic.grant(s, "relic_held_breath")
            Relic.grant(s, "relic_yoked_company")
            Relic.grant(s, "relic_whetted_vow")
            local order = Relic.rules(s).order
            local seen = {}
            for i, name in ipairs(order) do seen[name] = i end
            assert(seen.halveMaxHealth and seen.sharedPool and seen.pinHealth, "all three rules are present")
            assert(seen.halveMaxHealth < seen.sharedPool, "maxima are adjusted before the pool is formed")
            assert(seen.sharedPool < seen.pinHealth, "and the pin is applied to whatever bar then exists")
        end,
    },
    {
        name = "the drop pool is rarity-weighted, sorted, and includes what the run already holds",
        fn = function()
            local pool = Relic.pool({})
            assert(#pool > 0, "there should be relics to draw")
            local function weightOf(id)
                for _, e in ipairs(pool) do if e.id == id then return e.weight end end
            end
            local common, rare = weightOf("relic_whetstone_tithe"), weightOf("relic_held_breath")
            assert(common and rare and common > rare, "a common is likelier than a rare; got " .. common .. " vs " .. rare)
            -- SORTED: two machines resolving the same seed must draw the same relic.
            for i = 2, #pool do assert(pool[i - 1].id < pool[i].id, "the pool is in stable id order") end
            -- A weight-0 relic is off the rollable shelf entirely (Honed Edge is a rest reward).
            assert(weightOf("relic_honed_edge") == nil, "a weight-0 relic never enters the pool")
            -- Exclusion is OPT-IN now: without it, held relics stay in so a duplicate can be drawn.
            local excl = Relic.pool({ exclude = { "relic_whetstone_tithe" } })
            assert(#excl == #pool - 1, "excluding a relic removes exactly it")
            for _, e in ipairs(excl) do assert(e.id ~= "relic_whetstone_tithe", "the excluded relic is gone") end
        end,
    },
    {
        name = "the pool narrows to one rung when asked",
        fn = function()
            local rares = Relic.pool({ tier = "rare" })
            assert(#rares > 0, "there should be rares to draw")
            for _, e in ipairs(rares) do assert(e.def.tier == "rare", "a rare-only pool yields only rares") end
        end,
    },
    {
        name = "roll draws an id from the pool by weight (a single-entry pool is deterministic)",
        fn = function()
            assert(Relic.roll({ { id = "relic_full_skin", weight = 1 } }) == "relic_full_skin",
                "a one-relic pool always rolls that relic")
            assert(Relic.roll({}) == nil, "an empty pool rolls nil")
        end,
    },
    {
        name = "the slate deals distinct cards and can offer a relic the run already holds",
        fn = function()
            local heldOffered = false
            for _ = 1, 200 do
                local ids = Relic.slate({}, 3)
                assert(#ids == 3, "a healthy shelf fills all three slots")
                local seen = {}
                for _, id in ipairs(ids) do
                    assert(not seen[id], "a slate never repeats a card")
                    seen[id] = true
                end
                if seen["relic_whetstone_tithe"] then heldOffered = true end
            end
            -- The slate does not exclude held relics -- that inversion IS the stacking mechanism. Proven
            -- by asking for a slate while holding something and seeing it can still come up.
            assert(heldOffered, "the shelf can offer a relic over 200 draws")
            local s = Relic.newState()
            Relic.grant(s, "relic_whetstone_tithe")
            local found = false
            for _ = 1, 200 do
                for _, id in ipairs(Relic.slate({}, 3)) do
                    if id == "relic_whetstone_tithe" then found = true end
                end
            end
            assert(found, "a held relic stays in the pool, so a duplicate can be drawn and deepen it")
        end,
    },
    {
        name = "a circle's shelf leans toward its own, without ever closing to the rest",
        fn = function()
            local function weightOf(pool, id)
                for _, e in ipairs(pool) do if e.id == id then return e.weight end end
            end
            local tagged = 0
            for id, def in pairs(Relic.defs) do
                if def.sin and (def.weight or 1) > 0 then
                    tagged = tagged + 1
                    local home = weightOf(Relic.pool({ prestige = 20, sin = def.sin }), id)
                    local away = weightOf(Relic.pool({ prestige = 20, sin = "not_a_sin" }), id)
                    assert(home and away, id .. " fell out of the pool entirely")
                    assert(home > away, id .. " is no likelier on a " .. def.sin .. " floor than off it")
                end
            end
            assert(tagged >= 3, "the circles want something of their own on the shelf; found " .. tagged)
            local pool = Relic.pool({ prestige = 20, sin = "sloth" })
            local offCircle = 0
            for _, e in ipairs(pool) do if e.def.sin ~= "sloth" then offCircle = offCircle + 1 end end
            assert(offCircle > 0, "a circle's floor must still be able to offer somebody else's relic")
        end,
    },
    {
        name = "dispatch fires only held relics' hooks, namespaces scratch by id, and notifies",
        fn = function()
            local a = char("ally_a", { 30, 60 })
            local ctx = ctxFor({ a }, { cell = { x = 2, y = 3, encounter = { kind = "combat" } } })
            Relic.grant(ctx.state, "relic_deep_larder")
            local seen = {}
            ctx.notify = function(m) seen[#seen + 1] = m end
            Relic.dispatch("encounterCleared", ctx)
            assert(a.stats.health.current == 36, "The Deep Larder heals 6 after a fight (30 -> 36)")
            assert(ctx.state.scratch["relic_deep_larder"], "the relic's scratch is namespaced by id")
            assert(#seen == 1 and seen[1]:match("Larder"), "a firing relic pushes a toast")
            local ctx2 = ctxFor({ char("b", { 30, 60 }) })
            Relic.dispatch("encounterCleared", ctx2)
            assert(ctx2.party[1].stats.health.current == 30, "an un-held relic must not pay")
        end,
    },
    {
        -- ctx.mag is what lets a HOOK ladder its own magnitude, the way the bag ladders a flat stat.
        name = "a hook reads its own stack depth through ctx.mag",
        fn = function()
            local a = char("ally", { 10, 90 })
            local ctx = ctxFor({ a }, { cell = { x = 1, y = 1 } })
            Relic.grant(ctx.state, "relic_deep_larder")
            Relic.grant(ctx.state, "relic_deep_larder")
            Relic.dispatch("encounterCleared", ctx)
            assert(a.stats.health.current == 19, "two Deep Larders heal 6 + 3 = 9 (10 -> 19); got "
                .. a.stats.health.current)
            assert(ctx.stacks == nil, "the per-relic binding is cleared after the dispatch")
        end,
    },
    {
        name = "a synthetic relic proves per-run scratch accumulates and banked reads it",
        fn = function()
            Relic.defs["relic_test_counter"] = {
                name = "Test Counter", tier = "common",
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
        name = "a battleStart relic queues opening boons through grantBoon, laddered by stack",
        fn = function()
            local a, b = char("ally_a", { 40, 40 }), char("ally_b", { 40, 40 })
            local ctx = ctxFor({ a, b })
            Relic.grant(ctx.state, "relic_duelists_spur")
            local boons = Relic.openingBoons(Relic.dispatch("battleStart", ctx))
            assert(#boons == 2, "Duelist's Spur queues a boon for each front-row unit")
            for _, boon in ipairs(boons) do
                assert(boon.id == "status_hasted", "the boon is Hasted")
                assert(boon.opts.duration == 3, "one copy is the authored base duration")
            end
            -- A second copy deepens the DURATION, which is how an opening boon stacks.
            local ctx2 = ctxFor({ a })
            Relic.grant(ctx2.state, "relic_duelists_spur")
            Relic.grant(ctx2.state, "relic_duelists_spur")
            local deeper = Relic.openingBoons(Relic.dispatch("battleStart", ctx2))
            assert(deeper[1].opts.duration == 4, "a second copy adds a turn; got " .. tostring(deeper[1].opts.duration))
        end,
    },
    {
        name = "a standing price wounds but never fells -- ctx.drain floors at 1",
        fn = function()
            local low = char("ally_low", nil, nil, { 2, 40 })
            local ctx = ctxFor({ low }, { cell = { x = 1, y = 1 }, spoils = { gold = 0 } })
            Relic.grant(ctx.state, "relic_gluttons_purse")
            Relic.dispatch("battleStart", ctx)
            assert(low.stats.stamina.current == 1, "the toll floors at 1, never fells (2 -> 1)")
        end,
    },
    {
        name = "blurbAt resolves a magnitude at the CURRENT stack, not the authored base",
        fn = function()
            local one = Relic.blurbAt("relic_whetstone_tithe", 1)
            local three = Relic.blurbAt("relic_whetstone_tithe", 3)
            assert(one:match("1 damage"), "one copy reads its base; got " .. one)
            assert(three:match("3 damage"), "three copies read the laddered value; got " .. three)
            assert(Relic.blurbAt("relic_held_breath", 1) ~= "", "a relic with no scale still returns its blurb")
        end,
    },
    {
        name = "grantedTraits collects each relic's trait ids with its scope, for battle setup",
        fn = function()
            local s = Relic.newState()
            Relic.grant(s, "relic_rank_and_file")
            Relic.grant(s, "relic_whetstone_tithe") -- a pure flat-stat relic contributes no trait
            local traits = Relic.grantedTraits(s)
            assert(#traits == 1, "only the trait relic grants a trait")
            assert(traits[1].trait == "trait_close_ranks" and traits[1].scope == "party",
                "Rank and File grants trait_close_ranks to the whole party")
        end,
    },
    {
        name = "combatTraitsByChar resolves each relic to the members that wear it",
        fn = function()
            local a, b = char("ally_a", { 40, 40 }), char("ally_b", { 40, 40 })
            local s = Relic.newState()
            Relic.grant(s, "relic_rank_and_file")
            Relic.grant(s, "relic_whetstone_tithe")
            local byChar = Relic.combatTraitsByChar(s, { party = { a, b } }, { a, b })
            assert(byChar[a] and byChar[a][1] == "trait_close_ranks", "ally A wears the relic's trait")
            assert(byChar[b] and byChar[b][1] == "trait_close_ranks", "ally B wears it too (party scope)")
            for _, ids in pairs(byChar) do assert(#ids == 1, "the flat-stat relic contributes no trait") end
        end,
    },
    {
        name = "Trait.attach folds a unit's relicTraits in with the character's own",
        fn = function()
            local Trait = require("models.trait")
            local unit = { char = { id = "ally", traits = {}, inventory = {} }, relicTraits = { "trait_close_ranks" } }
            Trait.attach(unit)
            assert(Trait.has(unit, "trait_close_ranks"), "a relic-granted trait attaches like an innate one")
        end,
    },
    {
        -- Every trait a relic names has to exist, or the relic is a silent no-op at battle setup.
        name = "every trait a relic names exists in the trait registry",
        fn = function()
            local Trait = require("models.trait")
            for id, def in pairs(Relic.defs) do
                for _, t in ipairs(def.traits or {}) do
                    assert(Trait.defs[t], id .. " names a trait that does not exist: " .. t)
                end
            end
        end,
    },
    {
        -- FORGET is the run's only removal, spent by the Altar's trade. It takes ONE copy, not the stack.
        name = "forget gives up a single copy, and only drops the relic when the last one goes",
        fn = function()
            local s = Relic.newState()
            Relic.grant(s, "relic_whetstone_tithe")
            Relic.grant(s, "relic_whetstone_tithe")
            Relic.grant(s, "relic_whetstone_tithe")
            Relic.grant(s, "relic_keen_edge")
            assert(Relic.forget(s, "relic_whetstone_tithe") == 2, "one copy goes, two remain")
            assert(#Relic.held(s) == 2, "and the relic is still carried, so still in the tray")
            assert(Relic.statBonus(s).damage == 2 + 3, "the bag re-reads at the shallower stack")
            Relic.forget(s, "relic_whetstone_tithe")
            assert(Relic.forget(s, "relic_whetstone_tithe") == 0, "the last copy goes")
            assert(not Relic.has(s, "relic_whetstone_tithe"), "and it stops being held")
            assert(#Relic.held(s) == 1, "leaving the tray with only what is left")
            assert(s.scratch["relic_whetstone_tithe"] == nil, "its run scratch is dropped with it")
            assert(Relic.forget(s, "relic_whetstone_tithe") == nil, "giving up what you do not hold is nil")
            assert(Relic.forget(s, "relic_not_a_real_id") == nil, "and an unknown id is too")
        end,
    },
    {
        -- The shelf is bought at three stops now, and all three price off the rung.
        name = "a relic's price climbs with the rung and with the depth",
        fn = function()
            local c = Relic.price("relic_whetstone_tithe", 1)
            local u = Relic.price("relic_keen_edge", 1)
            local r = Relic.price("relic_held_breath", 1)
            assert(c < u and u < r, "each rung costs more than the one below; " .. c .. "/" .. u .. "/" .. r)
            assert(Relic.price("relic_held_breath", 8) > r, "and a deeper floor charges more")
            assert(Relic.price("relic_not_a_real_id", 1) == 0, "an unknown id is priced at nothing")
        end,
    },
    {
        -- EVERY NUMBER ON A CARD IS A NUMBER. A relic is a decision priced against another relic, and a
        -- card that says "less defense" asks the player to take the price on faith -- which on the
        -- uncommon rung, whose whole job is trades, means a rung with no readable decisions on it.
        --
        -- Written as a word-list rather than a shape check because the failure is linguistic: nothing
        -- about "the company fights with less defense" is malformed, it is just unanswerable.
        name = "no relic describes a magnitude in words instead of digits",
        fn = function()
            local vague = { "less", "more", "a little", "somewhat", "slightly", "harder", "further",
                            "lowered", "winded", "a fraction", "halved", "reduced", "improved" }
            for id, def in pairs(Relic.defs) do
                for _, line in ipairs({ def.blurb, def.cost }) do
                    if line then
                        local low = line:lower()
                        for _, word in ipairs(vague) do
                            -- "%f[%a]" is a frontier pattern: word boundaries, so "fewer" does not trip
                            -- on "few" and "further" does not trip inside another word.
                            assert(not low:find("%f[%a]" .. word .. "%f[%A]"),
                                id .. " describes a magnitude as '" .. word .. "': " .. line)
                        end
                    end
                end
            end
        end,
    },
    {
        -- A `%d` with no scale behind it prints as a literal "%d" on the card, which is worse than vague.
        name = "every placeholder on a card has a ladder behind it, and resolves",
        fn = function()
            for id, def in pairs(Relic.defs) do
                if def.blurb and def.blurb:find("%%d") then
                    assert(def.scale, id .. "'s blurb has a %d with no `scale` to fill it")
                    local out = Relic.blurbAt(id, 2)
                    assert(not out:find("%%d"), id .. "'s blurb did not resolve: " .. out)
                    assert(out ~= Relic.blurbAt(id, 1), id .. "'s blurb reads identically at one and two")
                end
                if def.cost and def.cost:find("%%d") then
                    assert(def.costScale, id .. "'s cost has a %d with no `costScale` to fill it")
                    local out = Relic.costAt(id, 2)
                    assert(not out:find("%%d"), id .. "'s cost did not resolve: " .. out)
                end
                -- ...and a ladder with no placeholder is a number nobody will ever see.
                if def.costScale then
                    assert(def.cost and def.cost:find("%%d"), id .. " has a costScale but no %d to spend it on")
                end
            end
        end,
    },
    {
        -- The Merchant's shelf offers relics the run does NOT hold, and handed that count (0) to the
        -- reading -- which took the "not held" branch and printed the authored "%d" on the card. A zero
        -- stack is an offer, and an offer reads at the one copy taking it would grant.
        name = "an unheld relic reads at one copy rather than printing its placeholder",
        fn = function()
            for id, def in pairs(Relic.defs) do
                if def.blurb and def.blurb:find("%%d") then
                    local zero, none = Relic.blurbAt(id, 0), Relic.blurbAt(id)
                    assert(not zero:find("%%d"), id .. "'s blurb printed its placeholder at zero: " .. zero)
                    assert(zero == Relic.blurbAt(id, 1), id .. " reads differently unheld than at one copy")
                    assert(none == zero, id .. "'s blurb differs with no stack at all: " .. none)
                end
                if def.cost and def.cost:find("%%d") then
                    local zero = Relic.costAt(id, 0)
                    assert(not zero:find("%%d"), id .. "'s cost printed its placeholder at zero: " .. zero)
                    assert(zero == Relic.costAt(id, 1), id .. "'s price differs unheld from at one copy")
                end
            end
        end,
    },
    {
        name = "a price line ladders with the stack, exactly as the effect line does",
        fn = function()
            -- The Keen Edge is +3/-3 at one copy and +5/-5 at two; both halves must move together, or a
            -- card advertises a trade the game does not make.
            assert(Relic.blurbAt("relic_keen_edge", 1):find("3"), "one copy gains 3")
            assert(Relic.costAt("relic_keen_edge", 1):find("3"), "and costs 3")
            assert(Relic.blurbAt("relic_keen_edge", 2):find("5"), "two copies gain 5")
            assert(Relic.costAt("relic_keen_edge", 2):find("5"), "and cost 5")
            -- A price that genuinely does not move says so and is returned unchanged.
            local braced = Relic.costAt("relic_braced_stance", 3)
            assert(braced == Relic.get("relic_braced_stance").cost, "a flat price is returned as authored")
            assert(Relic.costAt("relic_whetstone_tithe", 1) == nil, "a relic with no price has no line")
        end,
    },
    {
        -- A relic state is written straight into the run save, so it must stay plain data.
        name = "the relic state round-trips as plain data",
        fn = function()
            local Save = require("models.save")
            local s = Relic.newState()
            Relic.grant(s, "relic_whetstone_tithe")
            Relic.grant(s, "relic_whetstone_tithe")
            Relic.grant(s, "relic_keen_edge")
            local ok, encoded = pcall(Save.encode, { relicState = s }, 0)
            assert(ok, "Save.encode must not raise on a relic state: " .. tostring(encoded))
            assert(encoded:match("counts"), "the stack counts are in the written form")
        end,
    },
}
