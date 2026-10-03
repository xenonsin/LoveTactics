-- SHADE'S TOUCH: the Shade's own blow (data/characters/character_shade.lua; "Envy's Bestiary", round 1). Its touch
-- leaves the target Rattled -- the injury's own status, laid for a fight's length (8) as the Lion's roar lays it.
-- The Rattle rides the blow (`inflicts`), so a miss leaves nothing.
local Curve = require("models.curve")

return {
    name = "Shade's Touch",
    description = "Inflicts Rattled.",
    flavor = "Cold, and then the feeling that you have forgotten something you were about to do.",
    sprite = "assets/items/weapon_shade_touch.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "dark", "magical", "melee" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(8, 18),
        effect = function(fx)
            fx.damage(fx.target, { inflicts = { id = "status_rattled", duration = 8 } })
        end,
    },
}
