-- WHEEL OF EYES: the Ophan's weapon, and its drop (reviewed 2026-09-30, "Pride's Bestiary"). A wheel within a
-- wheel, its rims full of eyes. It does not swing at anyone: it turns, and everything beside it is struck -- and
-- nothing beside it can step aside, because there is no side it is not looking at (`alwaysHits`, which
-- Combat.rollsToHit reads, so the forecast says 100 rather than lying).
--
-- A MACE, BY FAMILY: a weight on a rim, impact, two hands. It does not knock back -- the Morning Star is the
-- other mace that gives its shove up for something else -- because a blow that lands on every side at once has
-- no direction to throw anyone in. A Skirmisher's, because a skirmisher is the one who wades into the middle and
-- leaves again; this rewards the wading. The "cannot be flanked" half of the review has nothing to answer: this
-- game has no flanking bonus to refuse.
--
-- `unstocked`: a trophy, seen on the rack and never sold (docs/drops.md).
local Curve = require("models.curve")

-- THE RING AROUND THE WIELDER, whichever neighbour the aim names. Aimed at a tile rather than cast on
-- itself (the Titan's Chain's shape): a self-cast quotes no reach (tests/items_spec.lua), and Clear Out reads
-- a melee weapon's reach off this one (tests/tactics_ability_spec.lua), so the wheel needs a real range of 1.
local function ring(combat, tx, ty, unit)
    local cx, cy = unit and unit.x or tx, unit and unit.y or ty
    return { { x = cx + 1, y = cy }, { x = cx - 1, y = cy }, { x = cx, y = cy + 1 }, { x = cx, y = cy - 1 } }
end

return {
    name = "Wheel of Eyes",
    description = "Hits every adjacent foe. Can't be avoided.",
    flavor = "Their rims were full of eyes round about. The prophet was being polite about how many.",
    sprite = "assets/items/weapon_wheel_of_eyes.png",
    type = "weapon",
    tags = { "mace", "impact", "physical", "melee" },
    hands = 2,
    class = "skirmisher",
    unlockLevel = 9,
    unstocked = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1, -- what it reaches: the ring beside it (and what Clear Out reads off an adjacent melee weapon)
        speed = 4,
        alwaysHits = true,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(14, 24), -- the mace slot it unlocks from (tests/balance_spec.lua); the Ophan carries less arm behind it
        aoe = { cells = ring },
        ai = { priority = "high", act = "attack", when = { subject = "any_foe", test = "within", value = 1 } },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u ~= fx.user and u.alive and u.side ~= fx.user.side then fx.damage(u) end
            end
        end,
    },
}
