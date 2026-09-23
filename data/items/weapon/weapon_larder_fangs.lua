-- LARDER FANGS: the Larder Mother's bite, and LIQUEFY lives here rather than in a slot of its own. A
-- spider digests outside the body: the venom dissolves the prey and she drinks what it dissolved. So the
-- bite carries Digesting (data/status/status_digesting.lua) -- Poison that heals whoever inflicted it --
-- applied through fx.applyStatus, which names her as the applier, rather than `inflicts` (which lands
-- with nobody's name on it). Otherwise it is the line's bite: half again as hard on a Rooted body.
--
-- Folded into the weapon because her grid is exactly full (nine slots: see character_the_larder_mother)
-- and because the mechanic IS the bite -- there is no Liquefy without fangs to carry it.
local Curve = require("models.curve")

local PINNED_BONUS = 0.5

return {
    name = "Larder Fangs",
    description = "Inflicts Digesting, which heals the biter as it works. Deal 50% more damage to a Rooted foe.",
    flavor = "She does not eat what she kills. She eats what it turns into, a little later, at her leisure.",
    sprite = "assets/items/weapon_larder_fangs.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "bite", "physical", "melee", "pierce" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(7, 17),
        effect = function(fx)
            local target = fx.target
            if not target then return end
            local pinned = fx.hasStatus(target, "status_root")
            local bonus = pinned and math.floor(fx.amount * PINNED_BONUS) or 0
            local hit = fx.damage(target, { amount = fx.amount + bonus })
            if target.alive and (hit or 0) > 0 then fx.applyStatus(target, "status_digesting") end
        end,
    },
}
