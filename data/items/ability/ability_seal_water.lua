-- Immunity: Water -- a brief, absolute ward granting Immune: Water
-- (data/status/status_immune_water.lua): every water-tagged hit is voided to 0 for a short window.
-- Short and premium on purpose -- the answer to the one big blow, not a stance to live in. It is
-- the true 0 that no amount of Resistant: Water can reach.
--
-- The deeper half of the Hunters Lodge's pair, gated behind the ward that softens the same damage:
-- a house teaches you to take the blow before it teaches you to refuse it. Gluttony's country is
-- wet -- the crossing, the river, the drowned ground. See docs/vulnerability.md.
return {
    name = "Immunity: Water",
    description = "Wards yourself or an ally with Immune: Water.",
    flavor = "The flood arrives at a door that has decided not to exist.",
    sprite = "assets/items/ability_seal_water.png",
    type = "ability",
    tags = { "protective" },
    class = "hunter",
    price = 410,
    unlockQuests = 4,
    activeAbility = {
        target = "ally", -- includes the caster
        range = 2,
        speed = 3,
        cost = { stat = "mana", amount = 14 },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_immune_water")
        end,
    },
}
