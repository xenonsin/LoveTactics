-- Immunity: Impact -- a brief, absolute ward granting Immune: Impact
-- (data/status/status_immune_impact.lua): every impact-tagged hit is voided to 0 for a short
-- window. Short and premium on purpose -- the answer to the one big blow, not a stance to live in.
-- It is the true 0 that no amount of Resistant: Impact can reach.
--
-- The deeper half of the Colosseum's pair, gated behind the ward that softens the same damage: a
-- house teaches you to take the blow before it teaches you to refuse it. The Colosseum sells the
-- hammer, so it sells the answer to one. See docs/vulnerability.md.
return {
    name = "Immunity: Impact",
    description = "Wards yourself or an ally with Immune: Impact.",
    flavor = "The hammer falls on a body excused from the appointment.",
    sprite = "assets/items/ability_seal_impact.png",
    type = "ability",
    tags = { "protective" },
    class = "fighter",
    price = 80,
    unlockQuests = 0,
    activeAbility = {
        target = "ally", -- includes the caster
        range = 2,
        speed = 3,
        cost = { stat = "mana", amount = 14 },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_immune_impact")
        end,
    },
}
