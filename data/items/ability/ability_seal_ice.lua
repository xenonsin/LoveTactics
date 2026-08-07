-- Immunity: Ice -- a brief, absolute ward granting Immune: Ice (data/status/status_immune_ice.lua):
-- every ice-tagged hit is voided to 0 for a short window. Short and premium on purpose -- the
-- answer to the one big blow, not a stance to live in. It is the true 0 that no amount of
-- Resistant: Ice can reach.
--
-- The deeper half of the Bastion's pair, gated behind the ward that softens the same damage: a
-- house teaches you to take the blow before it teaches you to refuse it. The Rimeguard is already
-- knight armour -- the house that stands still in the cold learned it first. See
-- docs/vulnerability.md.
return {
    name = "Immunity: Ice",
    description = "Wards yourself or an ally with Immune: Ice.",
    flavor = "The frost reaches the skin and finds it was never invited.",
    sprite = "assets/items/ability_seal_ice.png",
    type = "ability",
    tags = { "protective" },
    class = "knight",
    price = 620,
    unlockQuests = 9,
    activeAbility = {
        target = "ally", -- includes the caster
        range = 2,
        speed = 3,
        cost = { stat = "mana", amount = 14 },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_immune_ice")
        end,
    },
}
