-- Tests for the barrier statuses (data/status/{physical,magical}_barrier.lua) and their combat
-- hook: a barrier of the incoming school negates one hit outright, is spent doing so, and lets the
-- other school through untouched. Pure logic, headless.

local Character = require("models.character")
local Combat = require("models.combat")
local Status = require("models.status")

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

return {
    {
        name = "a physical barrier negates the next physical hit, is consumed, and lets magic through",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) }, { unit("character_bandit", 1, 2) })
            local bandit = c.units[2]
            local hp0 = bandit.char.stats.health.current

            Status.apply(c, bandit, "status_physical_barrier")
            local dealt = Combat.dealFlatDamage(c, bandit, 30, { "physical" }, "test")
            assert(dealt == 0, "the physical hit is negated, got " .. dealt)
            assert(bandit.char.stats.health.current == hp0, "no health was lost")
            assert(not Status.has(bandit, "status_physical_barrier"), "the barrier is spent by the hit")

            -- Only that ONE hit is warded: the next physical blow lands in full.
            local again = Combat.dealFlatDamage(c, bandit, 30, { "physical" }, "test")
            assert(again > 0, "a second physical hit lands once the barrier is gone, got " .. again)
        end,
    },
    {
        name = "a physical barrier does nothing against a magical hit",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) }, { unit("character_bandit", 1, 2) })
            local bandit = c.units[2]
            bandit.char.stats.magicDefense = 0
            local hp0 = bandit.char.stats.health.current

            Status.apply(c, bandit, "status_physical_barrier")
            local dealt = Combat.dealFlatDamage(c, bandit, 20, { "magical" }, "test")
            assert(dealt == 20, "a magical hit passes straight through a physical barrier, got " .. dealt)
            assert(bandit.char.stats.health.current == hp0 - 20, "the magical hit landed in full")
            assert(Status.has(bandit, "status_physical_barrier"), "and the physical barrier is untouched")
        end,
    },
    {
        name = "a magical barrier negates a magical hit but not a physical one",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) }, { unit("character_bandit", 1, 2) })
            local bandit = c.units[2]
            bandit.char.stats.defense = 0

            Status.apply(c, bandit, "status_magical_barrier")
            assert(Combat.dealFlatDamage(c, bandit, 25, { "magical" }, "test") == 0,
                "the magical barrier eats the spell")
            assert(not Status.has(bandit, "status_magical_barrier"), "and is spent")

            Status.apply(c, bandit, "status_magical_barrier")
            assert(Combat.dealFlatDamage(c, bandit, 10, { "physical" }, "test") == 10,
                "but a physical blow passes through it")
            assert(Status.has(bandit, "status_magical_barrier"), "leaving the magical barrier intact")
        end,
    },
    {
        name = "the damage preview reports a warded hit as 0 without consuming the barrier",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) }, { unit("character_bandit", 1, 2) })
            local bandit = c.units[2]
            Status.apply(c, bandit, "status_physical_barrier")

            -- Combat.mitigatedDamage is the pure read the tooltip uses; it must see the negation but
            -- never spend the ward.
            assert(Combat.mitigatedDamage(bandit, 30, { "physical" }) == 0, "preview shows 0 for a warded hit")
            assert(Status.has(bandit, "status_physical_barrier"), "a hovered preview does not consume the barrier")
        end,
    },
}
