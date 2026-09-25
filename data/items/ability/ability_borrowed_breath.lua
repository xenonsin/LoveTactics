-- BORROWED BREATH: the Kobold Scale-Priest's fire, and the drop off it (approved as pitched, 2026-09-24,
-- "The Kobolds of Greed"). A cone of fire, +3 damage for EACH ALLY standing beside the caster.
--
-- PACK, ON A CASTER. The priest breathes with the dragon's borrowed fire and its choir around it, so the
-- answer is to break up the huddle before it breathes. Handed to the player it is a caster who wants to
-- be in the middle of the line rather than behind it. Counted at the cast, from the caster's own
-- neighbours -- the same count in the forecast and the swing (fx.amount + the choir).
local Curve = require("models.curve")
local PER_ALLY = 3

return {
    name = "Borrowed Breath",
    description = "Breathes a cone of fire. Increase its damage by 3 for each ally standing beside you.",
    flavor = "It is not their fire. They say so every time, and then they breathe it anyway.",
    sprite = "assets/items/ability_borrowed_breath.png",
    type = "ability",
    tags = { "fire", "magical", "breath" },
    class = "shaman",
    unlockLevel = 5,
    unstocked = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 2,
        speed = 5,
        cooldown = 10,
        cost = { stat = "mana", amount = 10 },
        aoe = { shape = "cone", length = 3 },
        damage = Curve.ramp(9, 19), -- slot 5's power (tests/balance_spec.lua)
        effect = function(fx)
            local Combat = require("models.combat")
            local choir = 0
            for _, u in ipairs(fx.unitsNear(fx.user.x, fx.user.y, 1)) do
                if u ~= fx.user and u.alive and u.side == fx.user.side and Combat.unitGap(u, fx.user) == 1 then
                    choir = choir + 1
                end
            end
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side ~= fx.user.side then fx.damage(u, { amount = fx.amount + PER_ALLY * choir }) end
            end
        end,
    },
}
