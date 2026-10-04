-- RIDE PAST: the Outrider's charge (data/characters/character_outrider.lua; models/toll.lua, Toll.ride). Mounted on
-- a hollow beast, it charges up to 4 tiles in a line, striking every body it passes through, and ends its move
-- beyond them. A charge with nowhere to come out -- a wall or another body right behind the last one -- stops dead,
-- lands nothing, and the Outrider is Stunned. Put your back to a wall or a body.
--
-- Aimed at a neighbouring tile, which names the lane (the spear's aim). `ride.planned` hands the Outrider's turn to
-- Toll.plan, which picks the lane through the most foes and keeps it off every foe's shoulder when there is none --
-- and which does not look behind the line it rides at, because that is the ride that stops dead.
--
-- Every body in the lane is struck, its own side's too: a mount at the gallop does not choose. A demon's blow burns.
local Curve = require("models.curve")
local Status = require("models.status")

return {
    name = "Ride Past",
    description = "Charges up to 4 tiles in a line through every body, striking each, and ends beyond them. Blocked, it is Stunned.",
    flavor = "The beast under it is hollow all the way through. So, in a sense, is the charge.",
    sprite = "assets/items/weapon_ride_past.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "pierce", "physical", "melee", "fire" },
    noSteal = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(12, 22),
        -- The lane the ride runs, so the forecast shows who is in the way.
        aoe = { shape = "line", length = 4 },
        ride = { length = 4, stunOnFail = true, planned = true },
        usable = function(unit)
            if Status.blocksMove(unit) then return false, "Cannot move" end
            return true
        end,
        effect = function(fx)
            require("models.toll").ride(fx, { length = 4, stunOnFail = true })
        end,
    },
}
