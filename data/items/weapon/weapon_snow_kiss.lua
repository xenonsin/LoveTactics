-- THE SNOW KISS: the Yuki-onna's natural weapon ("Sloth's Bestiary", 2026-10-04, approved: "her kiss on a sleeper
-- deals double and does not wake it").
--
-- DOUBLE ON A SLEEPER, AND THE SLEEPER SLEEPS ON. The Alraune's Nightshade is the same doubling with the opposite
-- ending -- its blow is the alarm clock, and this one is not (`sparesSleep`, Combat.sparesSleep). So a body her
-- Snow-Sleep put under is a body she kisses every turn until somebody wakes it: a Cure, or an ally's blow.
--
-- The whole blow doubles -- her magic as well as the kiss's own figure -- so the doubling is read here rather than
-- through `amount` alone. Paid in mana, so a snapped horn (the oni race's rule) takes the kiss off her.
-- ICE and MAGICAL. A natural weapon: no class, no price, noSteal.
local Curve = require("models.curve")

return {
    name = "Snow Kiss",
    description = "Deals double damage to a sleeping foe, and does not wake it.",
    flavor = "It is very cold, and then it is not cold at all. That is the part to worry about.",
    sprite = "assets/items/weapon_snow_kiss.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "ice", "magical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "mana", amount = 6 },
        damage = Curve.ramp(6, 16),
        effect = function(fx)
            local tgt = fx.target
            if not (tgt and fx.hasStatus(tgt, "status_sleep")) then return fx.damage(tgt) end
            -- Double the blow, not the figure: the kiss's own figure twice, plus her magic once more on top of
            -- the once Combat.dealDamage adds itself.
            local power = require("models.combat").flatStat(fx.user, "magicDamage")
            fx.damage(tgt, { amount = (fx.amount or 0) * 2 + power, sparesSleep = true })
        end,
    },
}
