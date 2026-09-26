-- BLOOD SCENT: the Redcap's hunt (reviewed 2026-09-26, round 2, "The Goblins of Wrath"): on its turn it blinks
-- beside any foe below half health within 6, strikes, and blinks back to where it stood -- the assassin's
-- blink-execute, which is the discipline it grows on. A body's own, never shelved: the Redcap's drops are the
-- Dipped Cap and its Pike.
--
-- The answer is to keep the company above half, so it has nowhere to blink -- or to guard the wounded and let
-- its cap dry (trait_drying_cap).
local Curve = require("models.curve")

return {
    name = "Blood Scent",
    description = "Blinks beside a foe below half health, strikes it, and blinks back.",
    flavor = "It does not see you. It smells the part of you that is already outside.",
    sprite = "assets/items/ability_blood_scent.png",
    type = "ability",
    tags = { "guile", "pierce", "physical" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 6,
        speed = 4,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(10, 24),
        effect = function(fx)
            local target = fx.target
            if not (target and target.alive) then return end
            if not require("models.combat").belowHalf(target) then return end
            local user = fx.user
            local ox, oy = user.x, user.y
            if require("models.combat").unitGap(user, target) > 1 then
                local x, y = fx.openTileNear(target.x, target.y)
                if not x then return end
                fx.teleportUser(x, y)
            end
            fx.damage(target)
            if user.x ~= ox or user.y ~= oy then fx.teleportUser(ox, oy) end
        end,
    },
}
