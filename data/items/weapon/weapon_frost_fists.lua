-- An ice elemental's natural weapon. A biting blow of cold, ice-tagged so it feeds on a Frozen or Wet
-- target the way the mage's frost spells do. It does not freeze on its own (that is the Ice Bolt's
-- work) -- an elemental that froze every foe it touched would be too much. `noSteal`: cold you cannot keep.
local Curve = require("models.curve")

return {
    name = "Frost Fists",
    description = "Batters an adjacent foe with biting cold.",
    flavor = "Cold you could never keep, off a thing that has nothing else to give.",
    sprite = "assets/items/frost_fists.png",
    type = "weapon",
    class = "creature",
    dropTier = 3,
    tags = { "natural", "ice", "magical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(7, 17),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
