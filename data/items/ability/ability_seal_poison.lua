-- Seal: Poison -- a brief, absolute ward granting Immune: Poison (data/status/status_immune_poison.lua): every
-- poison-tagged hit is voided to 0 for a short window. Short and premium on purpose -- the answer to the one
-- big blow, not a stance to live in. A deliberate BORROW that says so: warding an ally is usually the
-- priest's work (docs/classes.md), but a CATEGORICAL immunity to a damage type is arcane mastery
-- overreaching, which is pride's own sin -- the mage seals the type off where the priest only softens it.
-- It is the true 0 that no amount of Resistant: Poison can reach. See docs/vulnerability.md.
return {
    name = "Seal: Poison",
    description = "Wards yourself or an ally with Immune: Poison for a short time.",
    flavor = "The venom looks for a vein and finds a theorem.",
    sprite = "assets/items/ability_seal_poison.png",
    type = "ability",
    tags = { "protective", "arcane" },
    class = "mage",
    price = 260,
    repRank = 3,
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
