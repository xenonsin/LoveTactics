-- Tests for FORGING STOCK TAKING A SLOT (models/material.lua, 2026-11-02).
--
-- A material was a bare counter on the player, so the thing a company hauled the most of weighed nothing
-- in the bag. It is a stack in the stash or the pack now, and the rules this file holds are the ones that
-- make that true without moving anything else: it takes a slot and merges like a draught, the bag holds
-- it with no ceiling, it is never worn, a spend frees its slot, a save carries it (an old save's counter
-- is folded onto the shelf), and the toll never prices it. (A wipe DOES take the stock in the bag since
-- 2026-11-24 -- Descent.wipe, tests/send_up_spec.lua.)

local Player = require("models.player")
local Descent = require("models.descent")
local Save = require("models.save")
local Character = require("models.character")
local Material = require("models.material")

local SCRAP = "material_iron_scrap"
local STEEL = "material_steel_ingot"

local function countIn(list, id)
    local n, slots = 0, 0
    for _, it in ipairs(list or {}) do
        if it.id == id then n, slots = n + (it.quantity or 1), slots + 1 end
    end
    return n, slots
end

-- A company in town with nothing on its shelf, so every slot counted is one this file made.
local function bare()
    local player = Player.new()
    player.roster = { Character.instantiate("character_knight") }
    player.stash, player.pack = {}, {}
    return player
end

local function underground(player)
    player.descentRun = Descent.new(player, 1)
    player.descentRun.entry = Save.snapshot(player)
    return player
end

return {
    { name = "a new game's opening ore sits on the shelf as stacks", fn = function()
        local player = Player.new()
        assert(player.materials == nil, "the old counter is still on a new player")
        for id, n in pairs(Player.defaults.startingMaterials or {}) do
            assert(countIn(player.stash, id) == n, id .. " did not land on the shelf")
            assert(Player.materialCount(player, id) == n, id .. " does not count")
        end
    end },

    { name = "stock merges into one slot until the stack is full, then opens another", fn = function()
        local player = bare()
        Player.addMaterial(player, SCRAP, 3)
        Player.addMaterial(player, SCRAP, 4)
        local n, slots = countIn(player.stash, SCRAP)
        assert(n == 7 and slots == 1, "seven scrap should be one stack, got " .. n .. " in " .. slots)
        Player.addMaterial(player, SCRAP, Material.MAX_STACK)
        n, slots = countIn(player.stash, SCRAP)
        assert(n == 7 + Material.MAX_STACK and slots == 2, "an overfull stack did not open a second slot")
        assert(Player.materialCount(player, SCRAP) == n, "the count disagrees with the shelf")
    end },

    { name = "underground stock lands in the bag, which has no ceiling", fn = function()
        -- (2026-11-24) The bag has no bottom (Descent.carryMax), so stock always lands.
        local player = underground(bare())
        for _ = 1, 50 do
            player.pack[#player.pack + 1] = require("models.item").instantiate("weapon_iron_sword")
        end
        assert(Player.addMaterial(player, SCRAP, 2) == 0, "a full-looking bag refused the stock")
        assert(Player.addMaterial(player, STEEL, 2) == 0, "the bag refused a new stack")
        assert(Descent.carried(player) == 52, "a stack of ore did not take a bag slot")
        assert(countIn(player.stash, SCRAP) == 0, "stock found underground reached the town shelf")
    end },

    { name = "a material is never worn: the equip gate refuses it", fn = function()
        local player = bare()
        Player.addMaterial(player, SCRAP, 2)
        local knight = player.roster[1]
        local ok, why = Character.canCarry(knight, player.stash[1])
        assert(not ok and type(why) == "string" and why ~= "", "a stack of ore can be equipped")
        assert(not Character.addItem(knight, player.stash[1]), "Character.addItem put ore in a grid")
    end },

    { name = "a spend reads both lists and gives an emptied slot back", fn = function()
        local player = bare()
        Player.addMaterial(player, SCRAP, 2)
        player.pack[#player.pack + 1] = Material.instantiate(SCRAP, 3)
        assert(Player.materialCount(player, SCRAP) == 5, "the bag's stock does not count in town")
        assert(not Player.spendMaterials(player, { [SCRAP] = 6 }), "a short bill was paid")
        assert(Player.materialCount(player, SCRAP) == 5, "a refused bill still took stock")
        assert(Player.spendMaterials(player, { [SCRAP] = 4 }), "an affordable bill was refused")
        assert(Player.materialCount(player, SCRAP) == 1, "the bill took the wrong amount")
        local _, slots = countIn(player.stash, SCRAP)
        assert(slots == 0, "an emptied stack kept its slot on the shelf")
    end },

    { name = "a save carries the stacks, and an old save's counter is folded onto the shelf", fn = function()
        local player = bare()
        Player.addMaterial(player, SCRAP, 5)
        player.pack[#player.pack + 1] = Material.instantiate(STEEL, 2)
        local back = Save.restore(Save.decode("return " .. Save.encode(Save.snapshot(player), 0)))
        assert(Player.materialCount(back, SCRAP) == 5, "the shelf's stock did not survive a save")
        assert(countIn(back.pack, STEEL) == 2, "the bag's stock did not survive a save")
        assert(back.stash[#back.stash].type == "material", "a restored stack is not a material")

        local snap = Save.snapshot(bare())
        snap.materials = { [SCRAP] = 4, material_not_a_thing = 9 }
        local old = Save.restore(snap)
        assert(Player.materialCount(old, SCRAP) == 4, "an old save's counter was not folded onto the shelf")
        assert(old.materials == nil, "the old counter survived the load beside the stacks")
    end },

    { name = "stock is never priced by the toll: the haul diff leaves it where it is", fn = function()
        local player = underground(bare())
        Player.addMaterial(player, SCRAP, 4)
        assert(next(Player.atRisk(player, player.descentRun.entry)) == nil, "found stock counts as at risk")
        Player.takeAtRisk(player, player.descentRun.entry)
        assert(Player.materialCount(player, SCRAP) == 4, "taking the haul took the stock with it")
    end },
}
