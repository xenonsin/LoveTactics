-- THE PASSING LANCE: what the Outrider drops (data/characters/character_outrider.lua; "Sloth's Bestiary", 2026-10-04,
-- slice F, approved word for word). Charge up to 4 tiles in a line through foes, striking each, and end beyond them.
--
-- The Outrider's Ride Past in a company's hands (models/toll.lua, Toll.ride), with the two things a rider's ride has
-- that a rider's lance should not: it passes through the company's own bodies without striking them, and a lane with
-- nowhere to come out simply stops the charge -- nothing lands, nothing moves, and nobody is Stunned. Rooted, it does
-- not ride at all.
--
-- A spear for the family's line (docs/weapons.md): the lane is its footprint, so the forecast shows who is in the
-- way. A VANGUARD'S, the shelf that decides where somebody else stands -- this decides where you do. An unstocked
-- trophy on the seat's rung.
local Curve = require("models.curve")
local Status = require("models.status")

return {
    name = "Passing Lance",
    description = "Charge up to 4 tiles in a line through foes, striking each, and end beyond them.",
    flavor = "It is not a weapon for meeting anybody. It is a weapon for having already gone.",
    sprite = "assets/items/weapon_passing_lance.png",
    type = "weapon",
    tags = { "spear", "pierce", "physical", "melee" },
    hands = 2,
    class = "vanguard",
    unlockLevel = 10,
    unstocked = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 10 },
        damage = Curve.ramp(13, 23), -- the slot-10 spear target (tests/balance_spec.lua)
        aoe = { shape = "line", length = 4 },
        ride = { length = 4, foesOnly = true },
        usable = function(unit)
            if Status.blocksMove(unit) then return false, "Cannot move" end
            return true
        end,
        effect = function(fx)
            require("models.toll").ride(fx, { length = 4, foesOnly = true })
        end,
    },
}
