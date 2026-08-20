-- Immunity: Acid -- a brief, absolute ward granting Immune: Acid
-- (data/status/status_immune_acid.lua): every acid-tagged hit is voided to 0 for a short window.
-- Short and premium on purpose -- the answer to the one big blow, not a stance to live in. It is
-- the true 0 that no amount of Resistant: Acid can reach.
--
-- The deeper half of the Undercroft's pair, gated behind the ward that softens the same damage: a
-- house teaches you to take the blow before it teaches you to refuse it. A guild that opens locks
-- with it knows to the second how long it burns. See docs/vulnerability.md.
return {
    name = "Immunity: Acid",
    description = "Wards yourself or an ally with Immune: Acid.",
    flavor = "It reaches for the flesh and closes on the memory of it.",
    sprite = "assets/items/ability_seal_acid.png",
    type = "ability",
    tags = { "protective" },
    class = "rogue",
    price = 610,
    unlockQuests = 4,
    activeAbility = {
        target = "ally", -- includes the caster
        range = 2,
        speed = 3,
        cost = { stat = "mana", amount = 14 },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_immune_acid")
        end,
    },
}
