-- Tests for models/overworld_ability.lua: the companion overworld-ability dispatcher and each handler's
-- metric math, driven headlessly with synthetic party members, cells and a grid stub. Every handler is
-- pure logic over Player helpers + the passed ctx, so no window or love.graphics is needed.

local OverworldAbility = require("models.overworld_ability")
local Player = require("models.player")

-- A stand-in party member: an id (also the blueprint key the dispatcher can fall back to), an ability,
-- and resource pools as { current, max } tables.
local function char(id, ability, hp, mana, stam)
    return {
        id = id, name = id, overworldAbility = ability,
        stats = {
            health = hp and { current = hp[1], max = hp[2] } or nil,
            mana = mana and { current = mana[1], max = mana[2] } or nil,
            stamina = stam and { current = stam[1], max = stam[2] } or nil,
        },
    }
end

-- A minimal grid stub: a tunable node degree (for Kaya's dead-end test), an objective, and a reveal
-- recorder (for Gyeom).
local function gridStub(degree)
    return {
        objective = { x = 5, y = 5 },
        _deg = degree or 2,
        pathNeighbors = function(self) local t = {}; for _ = 1, self._deg do t[#t + 1] = true end; return t end,
        reveal = function(self, x, y, r) self.revealedAt = { x = x, y = y, r = r } end,
    }
end

local function combatCell() return { x = 2, y = 3, encounter = { kind = "combat" } } end

local function ctxFor(party, extra)
    local c = { player = { party = party, gold = 100 }, party = party, grid = gridStub(), state = {} }
    if extra then for k, v in pairs(extra) do c[k] = v end end
    return c
end

return {
    {
        name = "dispatch runs only the matching event hook and namespaces each ability's scratch",
        fn = function()
            local rowan = char("character_rowan", "vigil", { 20, 20 }, nil, { 4, 12 })
            local ctx = ctxFor({ rowan }, { cell = combatCell() })
            OverworldAbility.dispatch("encounterCleared", ctx)
            assert(ctx.state["character_rowan"], "the ability's bucket should be namespaced by char id")
            assert(ctx.state["character_rowan"].vigils == 1, "a clean combat win should bank one vigil")
            -- An event with no hook for this ability is a no-op (Vigil has no objectiveReached).
            OverworldAbility.dispatch("objectiveReached", ctx)
            assert(ctx.state["character_rowan"].vigils == 1, "objectiveReached must not touch vigils")
        end,
    },
    {
        name = "Rowan's Vigil banks clean wins and spends them as a front-row health buffer",
        fn = function()
            local rowan = char("character_rowan", "vigil", { 10, 20 })
            local ctx = ctxFor({ rowan }, { cell = combatCell() })
            OverworldAbility.dispatch("encounterCleared", ctx) -- clean win -> vigil 1
            OverworldAbility.dispatch("encounterCleared", ctx) -- clean win -> vigil 2
            assert(ctx.state["character_rowan"].vigils == 2, "two clean wins should bank two vigils")
            OverworldAbility.dispatch("battleStart", ctx)
            assert(rowan.stats.health.current == 16, "front row should gain 3*vigils health (10 -> 16)")
        end,
    },
    {
        name = "a casualty breaks Rowan's vigil streak",
        fn = function()
            local rowan = char("character_rowan", "vigil", { 20, 20 }, nil, { 12, 12 })
            local downed = char("character_extra", nil, { 0, 18 })
            local ctx = ctxFor({ rowan, downed }, { cell = combatCell() })
            OverworldAbility.dispatch("encounterCleared", ctx)
            assert(ctx.state["character_rowan"].vigils == 0, "a downed member should reset the vigil to 0")
        end,
    },
    {
        name = "Saber's Held Swing banks new ground (once per tile), heals on the win, then resets",
        fn = function()
            local saber = char("character_saber", "held_swing", { 40, 84 })
            local ctx = ctxFor({ saber }, { cell = combatCell() })
            -- Ten DISTINCT tiles bank ten steps...
            for i = 1, 10 do ctx.cell = { x = i, y = 1 }; OverworldAbility.dispatch("step", ctx) end
            assert(ctx.state["character_saber"].steps == 10, "ten distinct tiles should bank ten steps")
            -- ...but pacing over an already-walked tile banks nothing (no exploit).
            local paced = { x = 1, y = 1, paced = true }
            for _ = 1, 20 do ctx.cell = paced; OverworldAbility.dispatch("step", ctx) end
            assert(ctx.state["character_saber"].steps == 10, "re-walking a paced tile must not bank more")
            ctx.cell = combatCell()
            OverworldAbility.dispatch("encounterCleared", ctx)
            assert(saber.stats.health.current == 45, "10 steps -> floor(10/2)=5 health (40 -> 45)")
            assert(ctx.state["character_saber"].steps == 0, "the held swing resets when she fights")
        end,
    },
    {
        name = "Amana's Kept Trust heals the most-wounded after a fight",
        fn = function()
            local amana = char("character_amana", "kept_trust", { 62, 62 })
            local hurt = char("character_a", nil, { 5, 40 })
            local ok = char("character_b", nil, { 30, 40 })
            local ctx = ctxFor({ amana, hurt, ok }, { cell = combatCell() })
            OverworldAbility.dispatch("encounterCleared", ctx)
            assert(hurt.stats.health.current == 17, "the most-wounded should be healed by 12 (5 -> 17)")
            assert(ok.stats.health.current == 30, "a less-wounded member is left alone")
        end,
    },
    {
        name = "Ren's Aqua Vitae distils a dose per side-win and pours them into the party at the boss",
        fn = function()
            local ren = char("character_ren", "aqua_vitae", { 60, 60 }, { 46, 46 })
            local ally = char("character_c", nil, { 10, 40 }, { 2, 20 })
            local ctx = ctxFor({ ren, ally }, { cell = combatCell() })
            OverworldAbility.dispatch("encounterCleared", ctx)
            OverworldAbility.dispatch("encounterCleared", ctx)
            OverworldAbility.dispatch("encounterCleared", ctx)
            assert(ctx.state["character_ren"].doses == 3, "three side-wins should distil three doses")
            OverworldAbility.dispatch("objectiveReached", ctx)
            assert(ally.stats.health.current == 28, "3 doses -> +6*3=18 HP (10 -> 28)")
            assert(ally.stats.mana.current == 14, "3 doses -> +4*3=12 mana (2 -> 14)")
        end,
    },
    {
        name = "Kaya's Forage marks a tile, respects the run cap, and never re-forages",
        fn = function()
            local kaya = char("character_kaya", "forage", { 66, 66 })
            local ctx = ctxFor({ kaya })
            local startGold = ctx.player.gold
            -- Walk many distinct tiles; forage is chance-based, so assert bounds and the marking, not an
            -- exact yield. The run cap is 40.
            for i = 1, 300 do
                ctx.cell = { x = i, y = 1 }
                OverworldAbility.dispatch("step", ctx)
                assert(ctx.cell.foraged, "a stepped tile should be marked foraged")
            end
            local gained = ctx.player.gold - startGold
            assert(gained >= 0 and gained <= 40, "foraged gold should stay within the run cap, got " .. gained)
            -- Re-walking a foraged tile yields nothing more.
            local before = ctx.player.gold
            local seen = { x = 1, y = 1, foraged = true }
            ctx.cell = seen
            OverworldAbility.dispatch("step", ctx)
            assert(ctx.player.gold == before, "a foraged tile must never pay again")
        end,
    },
    {
        name = "Gyeom's Ledger widens vision and lifts the fog off the quarry after three fights",
        fn = function()
            local gyeom = char("character_gyeom", "ledger", { 56, 56 }, { 46, 46 })
            assert(OverworldAbility.visionBonus({ roster = { gyeom } }) == 1,
                "Gyeom in the company should grant +1 vision")
            assert(OverworldAbility.visionBonus({ roster = {} }) == 0, "no Ledger, no bonus")
            local ctx = ctxFor({ gyeom }, { cell = combatCell() })
            OverworldAbility.dispatch("encounterCleared", ctx)
            OverworldAbility.dispatch("encounterCleared", ctx)
            assert(not ctx.grid.revealedAt, "two fights is not yet enough study")
            OverworldAbility.dispatch("encounterCleared", ctx)
            assert(ctx.grid.revealedAt and ctx.grid.revealedAt.x == 5,
                "the third fight should reveal the objective's seat")
        end,
    },
    {
        name = "Kaya's Forage senses a reliquary within two tiles of her step",
        fn = function()
            local revealed = {}
            local grid = {
                rows = 5, cols = 5, cells = {},
                pathNeighbors = function() return { true, true } end,
                reveal = function(_, x, y) revealed[x .. "," .. y] = true end,
            }
            for y = 1, 5 do grid.cells[y] = {}; for x = 1, 5 do grid.cells[y][x] = { x = x, y = y } end end
            grid.cells[3][4].encounter = { kind = "relic_cache" } -- the cell at (x=4, y=3)
            local kaya = char("character_kaya", "forage", { 40, 40 })
            local ctx = { player = { roster = { kaya }, gold = 0 }, party = { kaya }, grid = grid,
                state = {}, cell = grid.cells[3][3] } -- step onto (3,3): the cache at (4,3) is within 2
            OverworldAbility.dispatch("step", ctx)
            assert(revealed["4,3"], "a reliquary within two tiles surfaces through the fog")
        end,
    },
    {
        name = "Gyeom's Ledger reveals every reliquary on the board when her study completes",
        fn = function()
            local revealed = {}
            local grid = {
                objective = { x = 1, y = 1 }, rows = 3, cols = 3, cells = {},
                reveal = function(_, x, y) revealed[x .. "," .. y] = true end,
            }
            for y = 1, 3 do grid.cells[y] = {}; for x = 1, 3 do grid.cells[y][x] = { x = x, y = y } end end
            grid.cells[2][2].encounter = { kind = "relic_cache" }
            local gyeom = char("character_gyeom", "ledger", { 40, 40 })
            local ctx = { player = { party = { gyeom } }, party = { gyeom }, grid = grid, state = {},
                cell = { x = 2, y = 3, encounter = { kind = "combat" } } }
            for _ = 1, 3 do OverworldAbility.dispatch("encounterCleared", ctx) end
            assert(revealed["1,1"], "the objective's seat is revealed")
            assert(revealed["2,2"], "and every reliquary on the board")
        end,
    },
    {
        name = "a firing ability notifies (drives the overworld toast), and bankedSummary reads the scratch",
        fn = function()
            local ren = char("character_ren", "aqua_vitae", { 60, 60 }, { 46, 46 })
            local seen = {}
            local ctx = ctxFor({ ren }, { cell = combatCell() })
            ctx.notify = function(msg) seen[#seen + 1] = msg end
            OverworldAbility.dispatch("encounterCleared", ctx)
            assert(#seen == 1 and seen[1]:match("Ren"), "distilling a dose should push a toast")
            assert(OverworldAbility.bankedSummary(ren, ctx.state["character_ren"]) == "1 dose",
                "bankedSummary should read the pending dose")
            assert(OverworldAbility.bankedSummary(ren, nil) == nil, "no bucket, no summary")
        end,
    },
    {
        -- A CUT OF THE FIGHT'S OWN COIN, which is scrip since the economy split (models/scrip.lua).
        -- Taking a quarter of a fight's scrip and handing back campaign gold would make this the one
        -- seam in the game that converts one purse into the other, which is the thing the split exists
        -- to prevent -- so the assertion is on the purse as much as on the arithmetic.
        name = "Clem's Jubilee takes a cut of the winnings on top of the spoils",
        fn = function()
            local clem = char("character_clem", "jubilee", { 54, 54 })
            local ctx = ctxFor({ clem }, { cell = combatCell(), spoils = { gold = 40 } })
            -- Read off `gold` rather than the retired `scrip` field: one purse (models/spoils.lua), so
            -- what Clem takes a share of is what the fight actually paid.
            local before = ctx.player.gold or 0
            OverworldAbility.dispatch("encounterCleared", ctx)
            assert((ctx.player.gold or 0) == before + 10,
                "Clem should add 25% of the 40 gold the fight paid (10)")
        end,
    },
}
