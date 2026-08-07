-- Immunity: Dark -- a brief, absolute ward granting Immune: Dark
-- (data/status/status_immune_dark.lua): every dark-tagged hit is voided to 0 for a short window.
-- Short and premium on purpose -- the answer to the one big blow, not a stance to live in. It is
-- the true 0 that no amount of Resistant: Dark can reach.
--
-- The deeper half of the Undercroft's pair, gated behind the ward that softens the same damage: a
-- house teaches you to take the blow before it teaches you to refuse it. Nobody answers the dark
-- faster than the people who work in it. See docs/vulnerability.md.
return {
    name = "Immunity: Dark",
    description = "Wards yourself or an ally with Immune: Dark.",
    flavor = "The Undercroft does not fear the dark. It has been further into it.",
    sprite = "assets/items/ability_seal_dark.png",
    type = "ability",
    tags = { "protective" },
    class = "rogue",
    price = 620,
    unlockQuests = 9,
    activeAbility = {
        target = "ally", -- includes the caster
        range = 2,
        speed = 3,
        cost = { stat = "mana", amount = 14 },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_immune_dark")
        end,
    },
}
