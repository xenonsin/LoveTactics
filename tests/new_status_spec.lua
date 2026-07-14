-- Tests for the four new status effects: Cripple (movement cut), Mark (defense cut), Blind (range cut,
-- floored at 1), and Charm's reversion on expiry. Pure logic, headless.

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

local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    char.traits = {}
    return { char = char, x = x, y = y }
end

return {
    {
        name = "Cripple reduces the unit's movement budget by 2",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit("bandit", 1, 1) }, {})
            local u = c.units[1]
            local before = Combat.moveBudget(u)
            Status.apply(c, u, "cripple")
            assert(Combat.moveBudget(u) == before - 2, "cripple should cut movement by 2")
        end,
    },
    {
        name = "Mark reduces effective defense so a hit lands for more",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit("bandit", 1, 1) }, {})
            local u = c.units[1]
            local base = 20 -- comfortably above the bandit's defense so nothing floors at 1
            local d0 = Combat.mitigatedDamage(u, base, { "physical" })
            Status.apply(c, u, "mark")
            local d1 = Combat.mitigatedDamage(u, base, { "physical" })
            assert(d1 == d0 + 5, "mark should cut defense by 5, so damage rises by 5")
        end,
    },
    {
        name = "Blind reduces ability range, but never below 1",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit("bandit", 1, 1) }, {})
            local u = c.units[1]
            local far = { range = 5 }
            local r0 = Combat.abilityRange(c, u, far)
            Status.apply(c, u, "blind")
            assert(Combat.abilityRange(c, u, far) == r0 - 2, "blind should cut range by 2")
            -- A range-1 ability stays usable at melee: the reach floors at 1, not 0 or negative.
            assert(Combat.abilityRange(c, u, { range = 1 }) == 1, "blind never drops range below 1")
        end,
    },
    {
        name = "Charm reverts a unit's side and control when it expires",
        fn = function()
            local c = Combat.new(arena(6, 6), {}, { unit("bandit", 1, 1) })
            local u = c.units[1]
            assert(u.side == "enemy", "the bandit starts on the enemy side")
            -- Mimic what the Charm ability's effect does before applying the status: stash + flip.
            u._charmSide, u._charmControl = u.side, u.control
            u.side, u.control = "party", "ai"
            Status.apply(c, u, "charm", { duration = 2 })
            assert(u.side == "party", "while charmed it fights on the party side")
            Status.tick(c, 5) -- run the clock past the duration
            assert(u.side == "enemy", "on expiry it reverts to the enemy side")
            assert(u._charmSide == nil, "the stash is cleared on reversion")
            assert(not Status.has(u, "charm"), "the charm status is gone")
        end,
    },
    {
        name = "Cleansing a charmed unit reverts its side (Charm is a curable debuff)",
        fn = function()
            local c = Combat.new(arena(6, 6), {}, { unit("bandit", 1, 1) })
            local u = c.units[1]
            local origSide, origControl = u.side, u.control
            u._charmSide, u._charmControl = u.side, u.control
            u.side, u.control = "party", "ai"
            Status.apply(c, u, "charm", { duration = 5 })
            assert(u.side == "party", "charmed onto the party side")
            -- Cure strips the debuff; the teardown must still fire so the flip is undone.
            Combat.cleanse(c, u)
            assert(not Status.has(u, "charm"), "Cure strips the charm")
            assert(u.side == origSide and u.control == origControl, "and it reverts to its own side and control")
            assert(u._charmSide == nil, "the stash is cleared on reversion")
        end,
    },
}
