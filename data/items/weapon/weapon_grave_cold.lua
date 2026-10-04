-- GRAVE-COLD: the Cairn-Keeper's own blow (data/characters/character_cairn_keeper.lua; "Sloth's Bestiary",
-- 2026-10-04, slice C). The Keeper holds a grave at the back of the line, so its blow is thrown from there: the
-- mire's cold, reaching up through the ice at whoever it can see. Undead cold, not frost magic -- so it is
-- warded by Magic Defense and carries ice for the coats that answer it.
local Curve = require("models.curve")

return {
    name = "Grave-Cold",
    description = "Strikes a foe it can see.",
    flavor = "It comes up through the ice from somewhere much colder.",
    sprite = "assets/items/weapon_grave_cold.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "ice", "magical", "ranged" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(8, 18),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
