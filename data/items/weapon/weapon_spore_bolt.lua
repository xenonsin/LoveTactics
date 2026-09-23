-- Spore Bolt: the Thurifer's reach -- a knot of spores flung at a foe, which poisons where it lands.
--
-- The mushroom folk's one piece of plain magical damage, so the party of three is a mix the way the
-- brief asked: a Verger's physical staff in front, a Puffer's poison in the middle, and this from the
-- back. The Poison rides inside the hit (`inflicts`), so a miss takes it with the wound.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

return {
    name = "Spore Bolt",
    description = "Inflicts Poison.",
    flavor = "It is not aimed so much as released. The air does the aiming.",
    sprite = "assets/items/spore_bolt.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "poison", "magical", "ranged" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 4,
        requiresSight = true,
        speed = 5,
        cost = { stat = "mana", amount = 8 },
        damage = Curve.ramp(5, 15),
        effect = function(fx)
            fx.damage(fx.target, { inflicts = "status_poison" })
        end,
    },
}
