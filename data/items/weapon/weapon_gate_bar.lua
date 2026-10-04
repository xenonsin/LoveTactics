-- THE GATE-BAR: what the Bailiff swings (data/characters/character_bailiff.lua) -- the beam off the gate it keeps. Its
-- rule is the Barrier, not the blow, so the blow is plain: one foe beside it, and it burns, as a demon's does
-- (docs/bestiary.md). Unstealable, on no shelf; its drop is the Bailiff's Bar.
local Curve = require("models.curve")

return {
    name = "Gate-Bar",
    description = "Strikes an adjacent foe.",
    flavor = "It was the gate's before it was the Bailiff's, and it has not decided which it prefers.",
    sprite = "assets/items/weapon_gate_bar.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "impact", "physical", "melee", "fire" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(11, 21),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
