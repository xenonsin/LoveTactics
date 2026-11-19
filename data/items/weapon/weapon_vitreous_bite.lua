-- A glass-eater's bite. It spoils rather than kills: it strips harder than the swarm and hits softer
-- than anything else on its rung.
--
-- The Envy circle is the one stratum whose line body is not a damage problem. What it takes is the
-- shape you built -- the buffs, the wards, the stance you spent turns setting up -- and it takes enough
-- of it that ignoring the body is not an option even though the body cannot kill you.
--
-- Which is the sin as tactics. Envy does not want to beat you; it wants you to stop being better than
-- it, and it will spend the whole fight on that instead of on winning.
--
-- AND NOW IT KEEPS WHAT IT TAKES (creature identity pass, 2026-11-19). "Ignoring the body is not an option" was
-- a promise only the floor-12 mirror kept; on floor 11 nothing cashed the stripping in, and the eater was the
-- body you left for last. Every blessing it strips is a stack of Glass-Fed on the eater (+2 damage each, the
-- count on its badge, data/status/status_glass_fed.lua). Its lever is ORDER: an eater that has fed is the next
-- kill, or the next Dispel. The Unwanted bites with the same jaw and feeds the same way.
local Curve = require("models.curve")

return {
    name = "Vitreous Bite",
    description = "Bites an adjacent foe and strips two blessings from it. Each blessing stripped gives its bearer a stack of Glass-Fed.",
    flavor = "It has eaten a great deal of what other people made. It has never once made anything.",
    sprite = "assets/items/vitreous_bite.png",
    type = "weapon",
    class = "creature",
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
            -- What it strips, it keeps: one stack of Glass-Fed per blessing taken, on the eater.
            local taken = fx.dispelUnit(fx.target, 2) or {}
            if #taken > 0 then
                fx.applyStatus(fx.user, "status_glass_fed", { magnitude = #taken, applier = fx.user })
            end
        end,
    },
}
