-- Immunity: Holy -- a brief, absolute ward granting Immune: Holy
-- (data/status/status_immune_holy.lua): every holy-tagged hit is voided to 0 for a short window.
-- Short and premium on purpose -- the answer to the one big blow, not a stance to live in. It is
-- the true 0 that no amount of Resistant: Holy can reach.
--
-- The deeper half of the Cathedral's pair, gated behind the ward that softens the same damage: a
-- house teaches you to take the blow before it teaches you to refuse it. Holy is the Cathedral's
-- word (docs/classes.md), and it is the one house that must ward against its own. See
-- docs/vulnerability.md.
return {
    name = "Immunity: Holy",
    description = "Wards yourself or an ally with Immune: Holy.",
    flavor = "Even judgment can be shown the door, if the door is drawn well enough.",
    sprite = "assets/items/ability_seal_holy.png",
    type = "ability",
    tags = { "protective" },
    class = "priest",
    price = 620,
    unlockQuests = 9,
    activeAbility = {
        target = "ally", -- includes the caster
        range = 2,
        speed = 3,
        cost = { stat = "mana", amount = 14 },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_immune_holy")
        end,
    },
}
