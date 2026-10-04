-- DESIDIA'S BREATH: what the face does with a turn it is awake for (data/characters/character_general_sloth.lua).
-- Her sweeps are the banked turns (models/desidia.lua); this is the ordinary one -- she cannot move, so it reaches.
-- Natural, unstealable and on no shelf, like every creature's body.
local Curve = require("models.curve")

return {
    name = "Desidia's Breath",
    description = "Breathes the glacier's cold on a foe within 4.",
    flavor = "A sigh, from something that has not needed to breathe in a very long time.",
    sprite = "assets/items/weapon_desidias_breath.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "ice", "magical", "ranged" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 4,
        speed = 5,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(14, 26),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
