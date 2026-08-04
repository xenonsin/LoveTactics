-- Immunity: Holy -- a brief, absolute ward granting Immune: Holy (data/status/status_immune_holy.lua): every
-- holy-tagged hit is voided to 0 for a short window. Short and premium on purpose -- the answer to the one
-- big blow, not a stance to live in. A deliberate BORROW that says so: warding an ally is usually the
-- priest's work (docs/classes.md), but a CATEGORICAL immunity to a damage type is arcane mastery
-- overreaching, which is pride's own sin -- the mage seals the type off where the priest only softens it.
-- It is the true 0 that no amount of Resistant: Holy can reach. See docs/vulnerability.md.
return {
    name = "Immunity: Holy",
    description = "Wards yourself or an ally with Immune: Holy.",
    flavor = "Even judgment can be shown the door, if the door is drawn well enough.",
    sprite = "assets/items/ability_seal_holy.png",
    type = "ability",
    tags = { "protective", "arcane" },
    class = "mage",
    price = 260,
    unlockQuests = 3,
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
