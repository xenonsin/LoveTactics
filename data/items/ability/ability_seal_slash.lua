-- Immunity: Slash -- a brief, absolute ward granting Immune: Slash (data/status/status_immune_slash.lua): every
-- slash-tagged hit is voided to 0 for a short window. Short and premium on purpose -- the answer to the one
-- big blow, not a stance to live in. A deliberate BORROW that says so: warding an ally is usually the
-- priest's work (docs/classes.md), but a CATEGORICAL immunity to a damage type is arcane mastery
-- overreaching, which is pride's own sin -- the mage seals the type off where the priest only softens it.
-- It is the true 0 that no amount of Resistant: Slash can reach. See docs/vulnerability.md.
return {
    name = "Immunity: Slash",
    description = "Wards yourself or an ally with Immune: Slash.",
    flavor = "The edge passes through where the body agreed, briefly, not to be.",
    sprite = "assets/items/ability_seal_slash.png",
    type = "ability",
    tags = { "protective", "arcane" },
    class = "mage",
    price = 260,
    unlockQuests = 5,
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
