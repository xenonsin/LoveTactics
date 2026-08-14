-- The two model-side pieces the padded card's overrule stands on (states/battle.lua's
-- battle.fireOverrule, data/quests/colosseum/quest_colosseum_slot_02.lua). The firing itself lives in a
-- state and cannot be loaded headless, so what is pinned here is everything underneath it: that the
-- block resolves to bodies on real ground, and that a body stamped `unkillable` cannot be put down.
--
-- Both are the kind of thing that fails silently. A `from` edge that resolves to nothing returns a nil
-- plan and Ira simply never walks out -- the fight would end in a victory the beat was written to take
-- away. And an `unkillable` that does not hold turns a scripted loss into a fight the player can win,
-- which leaves them walking into a scene about their own funeral.
--
-- Pure logic, headless. See tests/arena_aftermath_spec.lua for the authored block itself.

local Character = require("models.character")
local Combat = require("models.combat")
local Quest = require("models.quest")

local function arena(cols, rows)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

local function unit(id, x, y) return { char = Character.instantiate(id), x = x, y = y } end

local function overruleBlock()
    return Quest.defs["quest_colosseum_slot_02"].map.objective.win.overrule
end

return {
    {
        name = "the padded card's overrule resolves to a body standing on the far edge",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { unit("character_rowan", 4, 8) },
                { unit("character_bandit_chief", 4, 2) })
            -- The same call states/battle.lua makes: an overrule block is read as a wave plan, because
            -- "who arrives, from which edge, onto which free tiles" is one question however it is asked.
            local plan = Combat.previewWaveArrival(c, overruleBlock(), {})
            assert(plan, "the overrule resolves to an arrival plan, or she never walks out at all")
            assert(#plan.tiles == 1, "one body walks on, got " .. #plan.tiles)
            assert(plan.ids[1] == "character_general_wrath", "and it is the patron of the house")
            assert(plan.tiles[1].y == 1, "from the far gate, behind the house's own line")
            -- Blueprint-exact, and that is the point: she is not grown down to the party's level, so a
            -- slot-2 board gets the body from the end of the line.
            local ref = Character.defs["character_general_wrath"].stats.health
            assert(plan.chars[1].stats.health.max == ref,
                "she arrives at her own numbers, got " .. tostring(plan.chars[1].stats.health.max))
        end,
    },
    {
        name = "an unkillable body is held at 1 health however hard it is hit",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { unit("character_rowan", 1, 1) },
                { unit("character_general_wrath", 1, 2) })
            local ira = c.units[2]
            ira.unkillable = true

            local dealt = Combat.dealFlatDamage(c, ira, 9999, { "physical" }, "test")
            assert(dealt > 0, "the blow still lands: what the party does to her is real")
            assert(ira.alive, "and she is still standing")
            assert(ira.char.stats.health.current == 1,
                "held at 1, got " .. tostring(ira.char.stats.health.current))

            -- Not a once-per-fight save like Second Wind. It holds every time, forever.
            Combat.dealFlatDamage(c, ira, 9999, { "physical" }, "test")
            assert(ira.alive and ira.char.stats.health.current == 1, "and it holds on the next blow too")
        end,
    },
    {
        name = "the same body is mortal without the stamp",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { unit("character_rowan", 1, 1) },
                { unit("character_general_wrath", 1, 2) })
            local ira = c.units[2]
            Combat.dealFlatDamage(c, ira, 9999, { "physical" }, "test")
            assert(not ira.alive, "the stamp is a property of THIS fielding, never of the blueprint")
        end,
    },
}
