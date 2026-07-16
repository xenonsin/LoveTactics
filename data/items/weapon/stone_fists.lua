-- An earth elemental's natural weapon. Unlike its kin's magical strikes, this is a PHYSICAL crushing
-- blow -- it scales off Damage and is mitigated by Defense -- and carries the "crush" tag, so it
-- shatters a Frozen foe for bonus damage (the hammer to the mage's ice). `noSteal`: the mountain stays.
return {
    name = "Stone Fists",
    description = "Crush an adjacent foe; shatters the Frozen.",
    sprite = "assets/items/stone_fists.png",
    type = "weapon",
    tags = { "natural", "crush", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 6 },
        damage = { 8, 9, 10, 10, 11, 12, 13, 14, 14, 15, 16 },
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
