-- SHED PLATE: a body plated in slabs that a blow of WEIGHT knocks off (reviewed 2026-09-25, "The Golems
-- of Greed"). Four pieces wear it, and the item's `traitParams` say which plate and what it lands as:
--
--   plateStatus  the stacking status the plates are        (status_stone_plate, _gold_plate, ...)
--   plates       how many the fight opens with
--   shedAs       "rubble"   a rubble wall (data/walls/rubble.lua) -- the Earth Golem, Shale Plating
--                "heap"     a coin heap -- the Gold Golem, whose plates are gold (round 2)
--                "reclaim"  a coin heap its wearer can walk back over to put the plate on again -- Gilt
--                           Plating (hazard_coin_heap reads `plateOf`)
--
-- The slab lands on the clear tile beside the wearer furthest from whoever struck it -- "behind you",
-- away from the attacker -- and a plate with nowhere to land is still knocked off. Only IMPACT sheds a
-- plate: the mace is the answer to a golem, the way fire is the answer to Gluttony's moss.
--
-- `notAReaction`: nothing about a slab falling off is the body answering the blow, so a stunned golem
-- sheds exactly as an alert one does (models/trait.lua, Trait.onDamaged).
local Golem = require("models.golem")
local Status = require("models.status")

return {
    name = "Shed Plate",
    description = "Opens the fight plated. An impact blow knocks a plate off beside you.",
    notAReaction = true,
    onCombatStart = function(ctx)
        local status = ctx.param("plateStatus")
        local plates = ctx.param("plates", 1)
        if status and plates > 0 then
            Status.apply(ctx.combat, ctx.unit, status, { magnitude = plates })
        end
    end,
    onDamaged = function(ctx)
        local unit, combat = ctx.unit, ctx.combat
        local status = ctx.param("plateStatus")
        if not (unit and unit.alive and status and Golem.hasTag(ctx.tags, "impact")) then return end
        if not Status.spendStacks(combat, unit, status, 1) then return end
        local spot = Golem.tileBeside(combat, unit.x, unit.y, ctx.attacker)
        local shedAs = ctx.param("shedAs", "rubble")
        local who = (unit.char and unit.char.name) or "It"
        if spot and shedAs == "rubble" then
            require("models.wall").place(combat, spot.x, spot.y, "rubble", { side = unit.side })
            ctx.log("action", string.format("A slab breaks off %s and crashes to the floor.", who), unit)
        elseif spot then
            local heap = Golem.heap(combat, spot.x, spot.y)
            if heap and shedAs == "reclaim" then heap.plateOf = unit end
            ctx.log("action", string.format("A gold plate is knocked off %s.", who), unit)
        else
            ctx.log("action", string.format("A plate breaks off %s and shatters.", who), unit)
        end
    end,
}
