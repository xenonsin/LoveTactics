-- Immunity: Water -- a brief, absolute ward granting Immune: Water (data/status/status_immune_water.lua): every
-- water-tagged hit is voided to 0 for a short window. Short and premium on purpose -- the answer to the one
-- big blow, not a stance to live in. A deliberate BORROW that says so: warding an ally is usually the
-- priest's work (docs/classes.md), but a CATEGORICAL immunity to a damage type is arcane mastery
-- overreaching, which is pride's own sin -- the mage seals the type off where the priest only softens it.
-- It is the true 0 that no amount of Resistant: Water can reach. See docs/vulnerability.md.
return {
    name = "Immunity: Water",
    description = "Wards yourself or an ally with Immune: Water.",
    flavor = "The flood arrives at a door that has decided not to exist.",
    sprite = "assets/items/ability_seal_water.png",
    type = "ability",
    tags = { "protective", "arcane" },
    class = "mage",
    price = 260,
    unlockQuests = 6,
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
