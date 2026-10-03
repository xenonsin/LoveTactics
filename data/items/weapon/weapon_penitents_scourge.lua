-- PENITENT'S SCOURGE: the Sewn-Eyed Penitents' own (data/characters/character_sewn_eyed_penitent.lua; "Envy's
-- Bestiary", 2026-10-03, slice C). The knotted cord the terrace's envious were given to beat out the envy with,
-- turned outward. Their rule is who they strike (utility_sewn_eyes); this is what they strike with.
local Curve = require("models.curve")

return {
    name = "Penitent's Scourge",
    description = "Strikes an adjacent foe.",
    flavor = "It was meant for their own backs. They have stopped being able to tell.",
    sprite = "assets/items/weapon_penitents_scourge.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "slash", "physical", "melee" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(8, 18),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
