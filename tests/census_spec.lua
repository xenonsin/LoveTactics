-- Tests for the CENSUS gate (`unlock.field`): a signature that opens on what the board looks like
-- rather than on what its bearer has done. See the block comment above Combat.census.
--
-- The two properties that make it worth having a field of its own are the ones this file pins:
-- a census can be LOST (kill the poisoned and the gate shuts again), and it reports a COUNT so the
-- badge can show progress -- which a bare `when` predicate cannot. The third, purity, is pinned
-- because Combat.itemBlockReason runs this over every grid item on every redraw, the damage preview
-- runs it against an inert context, and the AI asks it while planning: if a census ever wrote to a
-- unit, all three would corrupt the board just by looking at it.
--
-- Pure logic, headless -- mirrors tests/ultimate_spec.lua.

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
    return { char = char, x = x, y = y }
end

-- A knight and three bandits spread far enough apart that `within` can tell them apart.
local function field()
    local c = Combat.new(arena(12, 12), { unit("character_rowan", 1, 1) },
        { unit("character_bandit", 2, 1), unit("character_bandit", 4, 4), unit("character_bandit", 10, 10) })
    return c, c.units[1], { c.units[2], c.units[3], c.units[4] }
end

return {
    {
        name = "a census counts what is standing, by side",
        fn = function()
            local c, knight, foes = field()
            assert(Combat.census(knight, { of = "unit", side = "foe" }, c) == 3, "three foes stand")
            assert(Combat.census(knight, { of = "unit", side = "self" }, c) == 1, "and one of it")
            -- `ally` excludes the bearer; `party` includes it. A lone knight is the sharpest case:
            -- the two answers differ by exactly the body doing the counting.
            assert(Combat.census(knight, { of = "unit", side = "ally" }, c) == 0, "it is not its own ally")
            assert(Combat.census(knight, { of = "unit", side = "party" }, c) == 1, "but it is its own party")
            assert(Combat.census(knight, { of = "unit" }, c) == 4, "and unsided counts the whole board")

            foes[1].alive = false
            assert(Combat.census(knight, { of = "unit", side = "foe" }, c) == 2,
                "the dead are not standing")
        end,
    },
    {
        name = "status, distance and health clauses AND together",
        fn = function()
            local c, knight, foes = field()
            Status.apply(c, foes[1], "status_poison")  -- adjacent
            Status.apply(c, foes[3], "status_poison")  -- across the board

            local poisoned = { of = "unit", side = "foe", status = "status_poison" }
            assert(Combat.census(knight, poisoned, c) == 2, "two carry it")

            -- Adding a clause can only ever narrow: of the two poisoned, one is within 3 tiles.
            local near = { of = "unit", side = "foe", status = "status_poison", within = 3 }
            assert(Combat.census(knight, near, c) == 1, "distance narrows it to the near one")

            -- ...and health narrows it again, to none, until one is actually hurt.
            local hurt = { of = "unit", side = "foe", status = "status_poison", within = 3, hpBelow = 0.5 }
            assert(Combat.census(knight, hurt, c) == 0, "neither is wounded yet")
            local hp = foes[1].char.stats.health
            hp.current = math.floor(hp.max * 0.25)
            assert(Combat.census(knight, hurt, c) == 1, "now the near poisoned one is also hurt")
        end,
    },
    {
        name = "a census gate opens, reports progress, and can be LOST again",
        fn = function()
            local c, knight, foes = field()
            -- Zosia's shape, shrunk: the Mother Vat wants five poisoned, this wants two.
            local unlock = { field = { of = "unit", side = "foe", status = "status_poison", count = 2 },
                             text = "2 foes carrying poison" }

            local met, cur, total = Combat.unlockReady(knight, unlock, "key", c)
            assert(not met and cur == 0 and total == 2, "an empty board reports 0/2, not a bare no")

            Status.apply(c, foes[1], "status_poison")
            met, cur = Combat.unlockReady(knight, unlock, "key", c)
            assert(not met and cur == 1, "one poisoned is 1/2 -- the progress a `when` could never give")

            Status.apply(c, foes[2], "status_poison")
            met, cur = Combat.unlockReady(knight, unlock, "key", c)
            assert(met and cur == 2, "two opens it")

            -- THE POINT OF A CENSUS: it is a board state you are keeping, not a total you have banked.
            foes[2].alive = false
            met, cur = Combat.unlockReady(knight, unlock, "key", c)
            assert(not met and cur == 1, "killing one shuts the gate again -- a tally could not do this")
        end,
    },
    {
        name = "a census never rebaselines, so spending it does not pin the readout at zero",
        fn = function()
            local c, knight, foes = field()
            local unlock = { field = { of = "unit", side = "foe", status = "status_poison", count = 1 } }
            Status.apply(c, foes[1], "status_poison")
            assert(Combat.unlockReady(knight, unlock, "key", c), "open")

            -- A repeatable TALLY unlock banks a baseline here so the requirement must be met again.
            -- A census has no running total to slice, so Combat.unlockSpend must leave it alone --
            -- otherwise the gate would re-lock while the board still satisfied it.
            Combat.unlockSpend(knight, unlock, "key")
            assert(not (knight.unlockBase and knight.unlockBase["key"]),
                "no baseline is written for a census")
            local met, cur = Combat.unlockReady(knight, unlock, "key", c)
            assert(met and cur == 1, "and it is still open, because the board still looks that way")
        end,
    },
    {
        name = "reading a census mutates nothing -- the preview and the AI both depend on it",
        fn = function()
            local c, knight, foes = field()
            Status.apply(c, foes[1], "status_poison")
            local spec = { of = "unit", side = "foe", status = "status_poison", within = 4, hpBelow = 1 }

            local before = {}
            for i, u in ipairs(c.units) do
                before[i] = { hp = u.char.stats.health.current, x = u.x, y = u.y, alive = u.alive }
            end

            for _ = 1, 5 do Combat.census(knight, spec, c) end

            for i, u in ipairs(c.units) do
                assert(u.char.stats.health.current == before[i].hp, "health untouched")
                assert(u.x == before[i].x and u.y == before[i].y, "position untouched")
                assert(u.alive == before[i].alive, "life untouched")
            end
            assert(not knight.unlockBase, "and no bookkeeping is written by a read")
        end,
    },
    {
        name = "hazards and traps are countable, and no board at all counts zero",
        fn = function()
            local c, knight = field()
            assert(Combat.census(knight, { of = "hazard" }, c) == 0, "a clean floor has no hazards")
            c.hazards[#c.hazards + 1] = { x = 3, y = 3, side = "party" }
            c.hazards[#c.hazards + 1] = { x = 5, y = 5, side = "enemy" }
            assert(Combat.census(knight, { of = "hazard" }, c) == 2, "both are counted")
            assert(Combat.census(knight, { of = "hazard", side = "party" }, c) == 1,
                "and a side clause reads the same field off a hazard as off a body")

            -- The Loadout screen scans items with no battle around them. A census must read as UNMET
            -- there rather than met-by-default, or every census signature would show ready in town.
            assert(Combat.census(knight, { of = "unit", side = "foe" }, nil) == 0,
                "no combat, no census")
            local met = Combat.unlockReady(knight, { field = { side = "foe", count = 1 } }, "key", nil)
            assert(not met, "and the gate stays shut outside a battle")
        end,
    },
    {
        name = "the badge label carries the census progress",
        fn = function()
            local c, knight, foes = field()
            local item = { activeAbility = { unlock = {
                field = { of = "unit", side = "foe", status = "status_poison", count = 3 },
                text = "3 foes carrying poison" } } }

            local label, met = Combat.unlockLabel(knight, item, c)
            assert(label == "3 foes carrying poison (0/3)", "authored text plus progress: " .. tostring(label))
            assert(not met, "and it is shut")

            Status.apply(c, foes[1], "status_poison")
            label = Combat.unlockLabel(knight, item, c)
            assert(label == "3 foes carrying poison (1/3)", "the count climbs: " .. tostring(label))

            -- An unauthored census still reads honestly rather than printing a verb it does not have.
            local bare = { activeAbility = { unlock = { field = { side = "foe", count = 2 } } } }
            label = Combat.unlockLabel(knight, bare, c)
            assert(label == "On the field (3/2)" or label == "On the field (2/2)",
                "fallback names itself and still counts: " .. tostring(label))
        end,
    },
}
