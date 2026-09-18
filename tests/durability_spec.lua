-- DURABILITY: what wears out, what it costs to mend, and what is left when it does not get mended.
--
-- A gold sink with teeth in it. Weapons and armour spend one point per FIGHT THEY ARE FIELDED IN, the
-- Forge mends for coin, and a piece given up for parts pays back stock of its own grade.
--
-- WHAT IS ACTUALLY AT RISK is not the subtraction. It is four rules that would each be invisible if
-- they broke:
--
--   * only weapons and armour wear -- a repair bill on a spellbook is a bug nobody would spot
--   * a natural weapon must never wear, because it cannot be taken off OR mended
--   * a broken piece must be REFUSED in combat, or wear is a number with no consequence
--   * wear must bill the fielded and never the benched, and never twice for one fight

local Item = require("models.item")
local Player = require("models.player")
local Forge = require("models.forge")
local Character = require("models.character")
local Save = require("models.save")
local Material = require("models.material")

local function reserialize(data)
    return Save.decode("return " .. Save.encode(data, 0))
end

-- The first thing in this body's grid that wears, or nil.
local function firstWorn(char)
    for _, it in ipairs(Character.eachItem(char)) do
        if it.durability then return it end
    end
    return nil
end

return {
    { name = "weapons and armour wear; nothing else in the catalogue does", fn = function()
        local worn, spared = 0, 0
        for id, def in pairs(Item.defs) do
            local probe = { id = id, type = def.type, noSteal = def.noSteal, bound = def.bound }
            local max = Item.durabilityMax(probe)
            if def.type == "weapon" or def.type == "armor" then
                if def.noSteal or def.bound then
                    assert(max == nil, id .. " is a body part or bound and still wears out -- it can "
                        .. "never be taken off OR mended, so the bar is a countdown to a dead body")
                    spared = spared + 1
                else
                    assert(max and max > 0, id .. " is gear and does not wear")
                    worn = worn + 1
                end
            else
                assert(max == nil, id .. " is a " .. tostring(def.type) .. " and wears out")
            end
        end
        assert(worn > 0, "nothing in the catalogue wears, so the system is inert")
        assert(spared > 0, "no natural weapon was exempted -- the guard is untested")
    end },

    { name = "a fielded body's kit wears and a benched body's does not", fn = function()
        local player = Player.new()
        local a = Character.instantiate("character_knight")
        local b = Character.instantiate("character_knight")
        player.roster = { a, b }

        local wa, wb = firstWorn(a), firstWorn(b)
        assert(wa and wb, "the fixture body carries nothing that wears -- retarget this case")
        local before = wa.durability

        -- Only `a` takes the field.
        Player.noteDeployed(player, { a })
        assert(wa.durability == before - 1, "the fielded body's kit did not wear")
        assert(wb.durability == before, "a body left in town was billed for a fight it did not fight")
    end },

    { name = "a piece wears down to broken, stays in the grid, and reads as broken", fn = function()
        local char = Character.instantiate("character_knight")
        local weapon = firstWorn(char)
        assert(weapon, "the fixture knight carries nothing that wears -- retarget this case")

        for _ = 1, weapon.durability - 1 do
            assert(not Item.wear(weapon, 1), "it broke early")
        end
        assert(Item.wear(weapon, 1), "the last point of wear did not report the break")
        assert(Item.isBroken(weapon), "it is at zero and does not read as broken")
        assert(not Item.wear(weapon, 1), "a broken piece reported breaking a second time")
        assert(weapon.durability == 0, "wear took a broken piece below zero")

        -- IT IS STILL THERE. Gear deleted out from under a player at the end of a fight, with no screen
        -- and no line, is the failure mode this system has to avoid.
        local found = false
        for _, it in ipairs(Character.eachItem(char)) do
            if it == weapon then found = true end
        end
        assert(found, "a broken weapon was removed from the grid by wearing out")
    end },

    { name = "the forge mends for gold, bills nothing for a whole piece, and refuses a poor company",
      fn = function()
        local player = Player.new()
        local char = Character.instantiate("character_knight")
        player.roster = { char }
        local weapon = firstWorn(char)
        assert(weapon, "no wearing piece on the fixture")

        assert(Forge.mendCost(weapon) == nil, "a whole piece was billed for mending")
        local ok, why = Forge.mend(player, weapon)
        assert(not ok and why == "whole", "mending a whole piece did something")

        local max = Item.durabilityMax(weapon)
        weapon.durability = 0
        local full = Forge.mendCost(weapon)
        assert(full and full > 0, "a broken piece costs nothing to mend")

        -- HALF A BAR IS HALF THE BILL. The price is legible without a table: mending costs about a
        -- tenth of what the thing is worth, scaled by what is missing.
        weapon.durability = math.floor(max / 2)
        local half = Forge.mendCost(weapon)
        assert(half < full, "mending half a bar costs as much as mending all of it")

        player.gold = 0
        weapon.durability = 0
        local ok2, why2 = Forge.mend(player, weapon)
        assert(not ok2 and why2 == "poor", "a company with no gold mended anyway")

        player.gold = full + 10
        local before = player.gold
        assert(Forge.mend(player, weapon), "a company that could pay was refused")
        assert(weapon.durability == max, "mending did not fill the bar")
        assert(player.gold == before - full, "the mend billed " .. (before - player.gold)
            .. " against a quoted " .. full)
    end },

    { name = "a piece given up for parts pays stock of its OWN grade, and leaves a hole", fn = function()
        local player = Player.new()
        local char = Character.instantiate("character_knight")
        player.roster = { char }

        local cell, weapon
        for c = 1, Character.MAX_INVENTORY do
            local it = char.inventory and char.inventory[c]
            if it and (it.type == "weapon" or it.type == "armor") then cell, weapon = c, it break end
        end
        assert(weapon, "no gear to scrap on the fixture")
        local want = Material.gradeFor(weapon)
        -- A fresh company already holds Player.defaults.startingMaterials, so this is measured as a
        -- DELTA rather than against zero -- the absolute count is somebody else's number.
        local before = Player.materialCount(player, want)

        local ok, pay = Forge.scrap(player, char, cell)
        assert(ok, "scrapping a piece of gear was refused")
        assert(pay.id == want, "a piece scrapped into " .. pay.id .. " rather than its own grade "
            .. want .. " -- the stock it pays back must be the stock that would have improved it")
        assert(Player.materialCount(player, want) == before + pay.count,
            "the stock did not land: " .. before .. " -> " .. Player.materialCount(player, want))
        assert(char.inventory[cell] == nil, "the scrapped cell was not emptied")
    end },

    { name = "wear survives the real serializer, and a broken piece does not mend itself on save",
      fn = function()
        local player = Player.new()
        local char = Character.instantiate("character_knight")
        player.roster = { char }
        local weapon = firstWorn(char)
        assert(weapon, "no wearing piece on the fixture")

        weapon.durability = 7
        local back = Save.restore(reserialize(Save.snapshot(player)))
        local got = firstWorn(back.roster[1])
        assert(got and got.durability == 7, "wear came back as " .. tostring(got and got.durability))

        -- A ZERO HAS TO SURVIVE. `durability or nil` would quietly mend every broken piece on save,
        -- which is the one state this whole system exists to produce.
        weapon.durability = 0
        local back2 = Save.restore(reserialize(Save.snapshot(player)))
        local got2
        for _, it in ipairs(Character.eachItem(back2.roster[1])) do
            if it.id == weapon.id then got2 = it break end
        end
        assert(got2 and got2.durability == 0,
            "a broken piece mended itself across a save (" .. tostring(got2 and got2.durability) .. ")")
    end },

    { name = "the bars are long enough that mending is a between-trips errand", fn = function()
        local Descent = require("models.descent")
        -- A floor bills 3-4 fights (measured, `. board-report`), so a four-floor trip is ~14.
        assert(Item.DURABILITY.weapon >= 12,
            "a weapon this brittle (" .. Item.DURABILITY.weapon .. ") breaks inside one trip, which "
            .. "makes mending a thing you think about underground where you cannot do it")
        assert(Item.DURABILITY.weapon <= Descent.FLOORS * 4,
            "a weapon that survives a whole stack unmaintained is not a sink")
        assert(Item.DURABILITY.armor > Item.DURABILITY.weapon,
            "armour is hit rather than hitting and should outlast a blade")
    end },
}
