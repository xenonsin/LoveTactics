-- A glass-eater's bite. It spoils rather than kills: it strips harder than the swarm and hits softer
-- than anything else on its rung.
--
-- The Envy circle is the one stratum whose line body is not a damage problem. What it takes is the
-- shape you built -- the buffs, the wards, the stance you spent turns setting up -- and it takes enough
-- of it that ignoring the body is not an option even though the body cannot kill you.
--
-- Which is the sin as tactics. Envy does not want to beat you; it wants you to stop being better than
-- it, and it will spend the whole fight on that instead of on winning.
local Curve = require("models.curve")

return {
    name = "Vitreous Bite",
    description = "Bites an adjacent foe and strips two blessings from it.",
    flavor = "It has eaten a great deal of what other people made. It has never once made anything.",
    sprite = "assets/items/vitreous_bite.png",
    type = "weapon",
    class = "creature",
    dropTier = 3,
    tags = { "natural", "pierce", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(6, 16), -- soft, and deliberately so
        effect = function(fx)
            fx.damage(fx.target)
            fx.dispelUnit(fx.target, 2)
        end,
    },
}
