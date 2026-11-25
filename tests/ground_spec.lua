-- Tests for WHAT A FULL BAG LEAVES ON THE GROUND (models/ground.lua): the surplus of a fight, a chest
-- or a cache lies on the cell it was found on, survives the floor's snapshot, and is picked up a piece at
-- a time as the bag has room.

local Player = require("models.player")
local Descent = require("models.descent")
local Save = require("models.save")
local Item = require("models.item")
local Character = require("models.character")
local Ground = require("models.ground")
local Overworld = require("models.overworld")

local function underground()
    local player = Player.new()
    player.roster = { Character.instantiate("character_knight") }
    player.descentRun = Descent.new(player, 1)
    player.descentRun.entry = Save.snapshot(player)
    return player
end

local SWORD = "weapon_iron_sword"
local POTION = "consumable_healing_potion"

-- THE BAG HAS NO BOTTOM (2026-11-24, Descent.carryMax), so the overflow mechanism is exercised against
-- a fixed cap handed in as Ground's `room` argument, which is what any future ceiling would pass.
local CAP = 10
local function room(player) return function() return CAP - #(player.pack or {}) end end

local function fill(player)
    player.pack = player.pack or {}
    while #player.pack < CAP do
        player.pack[#player.pack + 1] = Item.instantiate(SWORD)
    end
end

return {
    { name = "a dropped piece lies on the cell as plain data and keeps its level", fn = function()
        local cell = {}
        Ground.drop(cell, Item.instantiate(SWORD, nil, 2))
        assert(Ground.has(cell) and Ground.count(cell) == 1, "nothing lies on the cell")
        assert(cell.ground[1].id == SWORD and cell.ground[1].level == 2, "the snapshot lost the piece's level")
        assert(Save.encode(cell.ground, 0), "the pile does not serialize")
    end },

    { name = "a full bag picks up nothing and the pile stays", fn = function()
        local player = underground()
        fill(player)
        local cell = {}
        Ground.drop(cell, Item.instantiate(SWORD))
        local taken, left = Ground.pickUp(player, cell, room(player))
        assert(#taken == 0 and left == 1, "a full bag took a piece")
        assert(Ground.has(cell), "the pile vanished")
    end },

    { name = "a bag with room takes what fits and leaves the rest lying", fn = function()
        local player = underground()
        fill(player)
        table.remove(player.pack) -- one slot free
        local cell = {}
        Ground.drop(cell, Item.instantiate(SWORD))
        Ground.drop(cell, Item.instantiate(SWORD))
        local before = #player.pack
        local taken, left = Ground.pickUp(player, cell, room(player))
        assert(#taken == 1 and left == 1, "expected one taken, one left; got " .. #taken .. "/" .. left)
        assert(#player.pack == before + 1, "the piece did not reach the bag")
        assert(Ground.count(cell) == 1, "the pile did not keep the piece that did not fit")
        table.remove(player.pack)
        Ground.pickUp(player, cell, room(player))
        assert(not Ground.has(cell) and cell.ground == nil, "an emptied pile is still marked")
    end },

    { name = "a stack the bag can absorb is taken even when no slot is free", fn = function()
        local player = underground()
        fill(player)
        local held = Item.instantiate(POTION)
        held.quantity = 1
        player.pack[#player.pack] = held
        local cell = {}
        Ground.drop(cell, Item.instantiate(POTION))
        local taken = Ground.pickUp(player, cell, room(player))
        assert(#taken == 1 and held.quantity == 2, "a stack that tops up the bag was refused")
    end },

    { name = "with no cap given, the unbounded bag takes the whole pile", fn = function()
        local player = underground()
        for _ = 1, 40 do player.pack[#player.pack + 1] = Item.instantiate(SWORD) end
        local cell = {}
        Ground.drop(cell, Item.instantiate(SWORD))
        Ground.drop(cell, Item.instantiate(SWORD))
        local taken, left = Ground.pickUp(player, cell)
        assert(#taken == 2 and left == 0 and not Ground.has(cell), "the bag left a pile lying")
    end },

    { name = "a pile rides the floor's snapshot", fn = function()
        local grid = Overworld.generate({ cols = 9, rows = 9, seed = 7 })
        local c = grid:get(grid.start.x, grid.start.y)
        Ground.drop(c, Item.instantiate(SWORD))
        local back = Overworld.fromSnapshot(grid:snapshot())
        local r = back:get(grid.start.x, grid.start.y)
        assert(Ground.count(r) == 1 and r.ground[1].id == SWORD, "the pile did not survive the snapshot")
    end },
}
