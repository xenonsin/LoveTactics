-- Immunity: Pierce -- a brief, absolute ward granting Immune: Pierce
-- (data/status/status_immune_pierce.lua): every pierce-tagged hit is voided to 0 for a short
-- window. Short and premium on purpose -- the answer to the one big blow, not a stance to live in.
-- It is the true 0 that no amount of Resistant: Pierce can reach.
--
-- The deeper half of the Hunters Lodge's pair, gated behind the ward that softens the same damage:
-- a house teaches you to take the blow before it teaches you to refuse it. The Lodge sells the
-- piercing shot, which makes it the house that knows the seam. See docs/vulnerability.md.
return {
    name = "Immunity: Pierce",
    description = "Wards yourself or an ally with Immune: Pierce.",
    flavor = "The point arrives certain. Certainty is the first thing the working takes.",
    sprite = "assets/items/ability_seal_pierce.png",
    type = "ability",
    tags = { "protective" },
    class = "hunter",
    price = 80,
    unlockQuests = 0,
    activeAbility = {
        target = "ally", -- includes the caster
        range = 2,
        speed = 3,
        cost = { stat = "mana", amount = 14 },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_immune_pierce")
        end,
    },
}
