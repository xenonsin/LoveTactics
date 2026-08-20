-- Immunity: Lightning -- a brief, absolute ward granting Immune: Lightning
-- (data/status/status_immune_lightning.lua): every lightning-tagged hit is voided to 0 for a short
-- window. Short and premium on purpose -- the answer to the one big blow, not a stance to live in.
-- It is the true 0 that no amount of Resistant: Lightning can reach.
--
-- The deeper half of the Arcanum's pair, gated behind the ward that softens the same damage: a
-- house teaches you to take the blow before it teaches you to refuse it. The storm is the Arcanum's
-- own, and pride is what tells it no. See docs/vulnerability.md.
return {
    name = "Immunity: Lightning",
    description = "Wards yourself or an ally with Immune: Lightning.",
    flavor = "For one breath the storm is told no, and the storm obeys.",
    sprite = "assets/items/ability_seal_lightning.png",
    type = "ability",
    tags = { "protective" },
    class = "mage",
    price = 610,
    unlockQuests = 4,
    activeAbility = {
        target = "ally", -- includes the caster
        range = 2,
        speed = 3,
        cost = { stat = "mana", amount = 14 },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_immune_lightning")
        end,
    },
}
