-- An ice elemental's natural weapon. A biting blow of cold, ice-tagged so it feeds on a Frozen or Wet
-- target the way the mage's frost spells do. It does not freeze on its own (that is the Ice Bolt's
-- work) -- an elemental that froze every foe it touched would be too much. `noSteal`: cold you cannot keep.
return {
    name = "Frost Fists",
    description = "Batter an adjacent foe with biting cold.",
    sprite = "assets/items/frost_fists.png",
    type = "weapon",
    tags = { "natural", "ice", "magical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2,
        cost = { stat = "stamina", amount = 5 },
        damage = { 7, 8, 8, 9, 10, 11, 11, 12, 13, 13, 14 },
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
