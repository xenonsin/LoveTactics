-- Immunity: Slash -- a brief, absolute ward granting Immune: Slash
-- (data/status/status_immune_slash.lua): every slash-tagged hit is voided to 0 for a short window.
-- Short and premium on purpose -- the answer to the one big blow, not a stance to live in. It is
-- the true 0 that no amount of Resistant: Slash can reach.
--
-- The deeper half of the Bastion's pair, gated behind the ward that softens the same damage: a
-- house teaches you to take the blow before it teaches you to refuse it. Turning an edge is the
-- Bastion's entire trade, and this is that plate said as a working. See docs/vulnerability.md.
return {
    name = "Immunity: Slash",
    description = "Wards yourself or an ally with Immune: Slash.",
    flavor = "The edge passes through where the body agreed, briefly, not to be.",
    sprite = "assets/items/ability_seal_slash.png",
    type = "ability",
    tags = { "protective" },
    class = "knight",
    price = 610,
    unlockQuests = 4,
    activeAbility = {
        target = "ally", -- includes the caster
        range = 2,
        speed = 3,
        cost = { stat = "mana", amount = 14 },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_immune_slash")
        end,
    },
}
