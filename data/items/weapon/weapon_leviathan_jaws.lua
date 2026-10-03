-- LEVIATHAN'S JAWS: what the serpent does in the round it is up (data/characters/character_leviathan.lua). Its
-- rising is the heavy blow (models/leviathan.lua); this is only the bite of a head that has come up beside you.
--
-- A demon's blow burns (docs/bestiary.md, "...and a demon's blows burn"): `fire` is the element on a physical
-- channel, the Infernal Claws' reading, so the coats the Crucible sells against demons have something to answer.
-- Natural, unstealable and on no shelf, like every creature's body.
local Curve = require("models.curve")

return {
    name = "Leviathan's Jaws",
    description = "Bites an adjacent foe, and the wound burns.",
    flavor = "It has been swallowing the waste for longer than there has been a waste.",
    sprite = "assets/items/weapon_leviathan_jaws.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "bite", "pierce", "physical", "melee", "fire" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 5,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(14, 26),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
