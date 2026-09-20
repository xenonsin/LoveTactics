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

        -- HALF A BAR IS HALF THE BILL, and the bill is a FIXED RATE PER POINT rather than a share of
        -- what the piece is worth (Forge.MEND_PER_POINT). The share version read `item.price`, which
        -- the shelf recut took off everything above a house's opener -- so for most of the catalogue
        -- it collapsed onto the max(1, ...) floor and a destroyed endgame hammer mended for ONE GOLD.
        -- That is the failure this case now pins: the bill must be the WORK, and the work is the same
        -- whatever the blade is worth.
        assert(full == (max - 0) * Forge.MEND_PER_POINT, string.format(
            "a full bar of %d points billed %d, not %d at the fixed rate",
            max, full, max * Forge.MEND_PER_POINT))

        weapon.durability = math.floor(max / 2)
        local half = Forge.mendCost(weapon)
        assert(half < full, "mending half a bar costs as much as mending all of it")

        -- AND AN UNPRICED PIECE IS BILLED THE SAME AS A PRICED ONE. The whole hole in one assertion:
        -- pick something the recut left with no `price` at all and check it is not mending for the
        -- floor of 1. Structural -- it reads the item's own absent field -- so it stays true however
        -- the catalogue is re-priced.
        local found = Item.instantiate("armor_leather_armor")
        assert(Item.defs.armor_leather_armor.price == nil,
            "the fixture stopped being an unpriced ware; pick another")
        local fmax = Item.durabilityMax(found)
        found.durability = 0
        assert(Forge.mendCost(found) == fmax * Forge.MEND_PER_POINT,
            "an unpriced ware mends for " .. tostring(Forge.mendCost(found))
            .. " -- the bill is reading the piece's value again")

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

    { name = "a broken piece can still be broken down, through the one salvage path", fn = function()
        -- "WHEN THEY BREAK THEY TURN TO SCRAP" IS ALREADY A THING THIS GAME DOES (models/salvage.lua),
        -- and durability's job is to create the REASON to do it -- a piece too dear to mend -- rather
        -- than a second way. This case exists to stop anyone adding that second way: if a scrap verb
        -- ever appears on the Forge beside Salvage, the two will pay different numbers for one gesture.
        local Salvage = require("models.salvage")
        local player = Player.new()
        local char = Character.instantiate("character_knight")
        player.roster = { char }
        local weapon = firstWorn(char)
        assert(weapon, "no wearing piece on the fixture")

        weapon.durability = 0
        assert(Item.isBroken(weapon), "the fixture piece is not broken")
        assert(Salvage.canBreak(player, weapon),
            "a broken piece cannot be salvaged, so a company that cannot afford the mend is stuck "
            .. "with a dead grid cell: " .. tostring(Salvage.refusal(player, weapon)))

        local before = Player.materialCount(player, Salvage.craftGradeFor(Item.defs[weapon.id]))
        local yield = Salvage.breakDown(player, weapon)
        assert(yield and next(yield), "breaking a broken piece paid nothing")
        local after = Player.materialCount(player, Salvage.craftGradeFor(Item.defs[weapon.id]))
        assert(after > before, "the craft stock did not land: " .. before .. " -> " .. after)

        -- AND THERE IS NO SECOND PATH. Forge.scrap was written and deleted on exactly this reasoning.
        assert(require("models.forge").scrap == nil,
            "a second scrap verb has appeared on the Forge beside models/salvage.lua -- two answers "
            .. "to one question, and one of them will go stale")
        assert(Item.scrapFor == nil,
            "Item.scrapFor is back; what a broken piece is worth is Salvage's question")
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

    { name = "a piece is mended IN TOWN and nowhere else", fn = function()
        -- The case above states this rule in prose -- "mending is a thing you think about underground
        -- where you cannot do it" -- and until now nothing enforced it, which is the shape of rule
        -- that quietly stops being true. It matters more since data/status/status_corroding.lua: the
        -- slimes eat durability mid-fight, and the whole reason that is fair is that the answer is a
        -- trip home. An underground repair would delete the cost without deleting the mechanic.
        --
        -- Asserted on the CALL SITES rather than on a flag, because there is no flag to read -- the
        -- rule is "only a hub panel may spend this verb", and the only way to check it is to look at
        -- who calls it. Source-swept the way tests/item_coverage_spec.lua sweeps for named ids.
        local ALLOWED = { ["ui/panels/forge.lua"] = true }
        local offenders = {}
        local function sweep(dir)
            for _, entry in ipairs(love.filesystem.getDirectoryItems(dir)) do
                local path = dir .. "/" .. entry
                if love.filesystem.getInfo(path, "directory") then
                    sweep(path)
                elseif entry:match("%.lua$") then
                    local src = love.filesystem.read(path)
                    -- The model's own file defines the verb; it is not a caller of it.
                    if src and path ~= "models/forge.lua" and not ALLOWED[path]
                        and src:find("Forge%.mend%s*%(") then
                        offenders[#offenders + 1] = path
                    end
                end
            end
        end
        for _, root in ipairs({ "models", "states", "ui", "data", "tools" }) do sweep(root) end
        table.sort(offenders)
        assert(#offenders == 0, "gear is mended at the Bastion's forge and nowhere else, so a "
            .. "corroded blade is a reason to go home. These reach Forge.mend from outside the hub "
            .. "panel:\n  " .. table.concat(offenders, "\n  "))

        -- ...and the panel those call sites belong to really is a room on a house's desk, which is
        -- what makes it a town errand rather than something the run can carry with it.
        local Registry = require("models.registry")
        local buildings = Registry.load("data/buildings", "data.buildings")
        local found = false
        for _, def in pairs(buildings) do
            for _, offer in ipairs(def.offers or {}) do
                if offer.panel == "forge" then found = true end
            end
        end
        assert(found, "no house opens the forge, so the one place gear can be mended is unreachable")
    end },
}
