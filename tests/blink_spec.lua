-- Tests for Blink (data/items/ability/ability_blink.lua) and the teleport movement mode: an armed,
-- affordable blink reaches farther than a walk, ignores terrain and obstacles, spends mana instead
-- of move initiative, and falls back to a walk when it can't be paid. Headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Wall = require("models.wall")

local function arena(cols, rows)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

-- A mage carrying only the Blink item (so its default movement is the base stat).
local function blinkMage(x, y)
    local char = Character.instantiate("mage")
    char.inventory = {}
    Character.addItem(char, Item.instantiate("ability_blink"))
    return char, { char = char, x = x, y = y }
end

return {
    {
        name = "an armed blink reaches farther than a walk and ignores an obstacle in the way",
        fn = function()
            local char = blinkMage(1, 1)
            local c = Combat.new(arena(8, 8), { { char = char, x = 1, y = 1 } }, {})
            local u = c.units[1]
            u.blinkArmed = true

            -- Walk (movement 3) can't reach a tile 5 away; a blink (range 5) can.
            assert(Combat.reachable(c, u)["1,6"] == nil, "a movement-3 walk can't reach 5 tiles out")
            assert(Combat.teleportCells(c, u, 5)["1,6"], "but a blink can")

            -- A wall between the mage and a near tile doesn't bar the teleport onto the far side.
            Wall.place(c, 1, 2, "illusory_wall")
            assert(Combat.teleportCells(c, u, 5)["1,4"], "a blink lands past a wall it can't walk through")
        end,
    },
    {
        name = "blinking spends mana, jumps instantly, and spends the turn's one move",
        fn = function()
            local char = blinkMage(1, 1)
            local c = Combat.new(arena(8, 8), { { char = char, x = 1, y = 1 } }, {})
            local u = c.units[1]
            u.blinkArmed = true
            c.turn = { unit = u, moved = false, moveCost = 0 }

            local mana0 = char.stats.mana.current
            assert(Combat.blink(c, u, 1, 5), "the blink resolves")
            assert(u.x == 1 and u.y == 5, "the mage jumps straight to the target tile")
            assert(char.stats.mana.current == mana0 - 6, "one blink's mana (6) is spent")
            assert(c.turn.moved, "the turn's move is spent")
            assert(c.turn.moveCost == 0, "a blink owes no move initiative")

            -- No second move this turn.
            assert(Combat.blink(c, u, 1, 6) == false, "a unit can't blink again after moving")
        end,
    },
    {
        name = "a blink the unit can't afford is not offered (it falls back to a walk)",
        fn = function()
            local char = blinkMage(1, 1)
            local c = Combat.new(arena(8, 8), { { char = char, x = 1, y = 1 } }, {})
            local u = c.units[1]
            u.blinkArmed = true
            char.stats.mana.current = 2 -- less than the 6 a jump costs

            assert(Combat.blinkReady(u) == nil, "an unaffordable blink is not ready")
            c.turn = { unit = u, moved = false, moveCost = 0 }
            assert(Combat.blink(c, u, 1, 4) == false, "and cannot be performed")
        end,
    },
    {
        name = "blink is unavailable to a unit that carries no Blink item, however the flag is set",
        fn = function()
            local c = Combat.new(arena(8, 8), { { char = Character.instantiate("knight"), x = 1, y = 1 } }, {})
            local u = c.units[1]
            u.blinkArmed = true -- set, but there is no teleport item to honour it
            assert(Combat.blinkReady(u) == nil, "no blink without a blink item")
        end,
    },
}
