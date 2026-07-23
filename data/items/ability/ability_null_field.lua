-- Null Field: the mage half of the Spellbreaker (knight x mage). A quenching field that Silences a foe
-- (data/status/silenced.lua) -- it cannot spend mana to cast until it lifts. The anti-caster's negation,
-- spoken in the caster's own idiom: pride's own element turned against pride.
return {
    name = "Null Field",
    description = "Inflicts Silenced: the foe cannot cast mana abilities for a time.",
    flavor = "The Arcanum teaches that the art cannot be unmade. The Arcanum has not met a Spellbreaker.",
    sprite = "assets/items/ability_null_field.png",
    type = "ability",
    tags = { "utility" },
    class = "mage",
    discipline = "spellbreaker", -- knight x mage; the Counterspell mechanic's first stock
    price = 240,
    repRank = 3,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 4,
        cost = { stat = "mana", amount = 10 },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_silenced")
        end,
    },
}
