-- Immunity: Fire -- a brief, absolute ward granting Immune: Fire
-- (data/status/status_immune_fire.lua): every fire-tagged hit is voided to 0 for a short window.
-- Short and premium on purpose -- the answer to the one big blow, not a stance to live in. It is
-- the true 0 that no amount of Resistant: Fire can reach.
--
-- The deeper half of the Colosseum's pair, gated behind the ward that softens the same damage: a
-- house teaches you to take the blow before it teaches you to refuse it. The pit has watched enough
-- men go up to know exactly how it is survived. See docs/vulnerability.md.
return {
    name = "Immunity: Fire",
    description = "Wards yourself or an ally with Immune: Fire.",
    flavor = "Resistance argues with the fire. This does not argue.",
    sprite = "assets/items/ability_seal_fire.png",
    type = "ability",
    tags = { "protective" },
    class = "fighter",
    price = 410,
    unlockQuests = 4,
    activeAbility = {
        target = "ally", -- includes the caster
        range = 2,
        speed = 3,
        cost = { stat = "mana", amount = 14 },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_immune_fire")
        end,
    },
}
