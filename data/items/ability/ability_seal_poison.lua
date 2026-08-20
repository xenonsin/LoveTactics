-- Immunity: Poison -- a brief, absolute ward granting Immune: Poison
-- (data/status/status_immune_poison.lua): every poison-tagged hit is voided to 0 for a short
-- window. Short and premium on purpose -- the answer to the one big blow, not a stance to live in.
-- It is the true 0 that no amount of Resistant: Poison can reach.
--
-- The deeper half of the Crucible's pair, gated behind the ward that softens the same damage: a
-- house teaches you to take the blow before it teaches you to refuse it. Poison is envy's own
-- (docs/classes.md), and the vats that brew it keep the antidote on the same bench. See
-- docs/vulnerability.md.
return {
    name = "Immunity: Poison",
    description = "Wards yourself or an ally with Immune: Poison.",
    flavor = "The venom looks for a vein and finds a theorem.",
    sprite = "assets/items/ability_seal_poison.png",
    type = "ability",
    tags = { "protective" },
    class = "alchemist",
    price = 610,
    unlockQuests = 4,
    activeAbility = {
        target = "ally", -- includes the caster
        range = 2,
        speed = 3,
        cost = { stat = "mana", amount = 14 },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_immune_poison")
        end,
    },
}
