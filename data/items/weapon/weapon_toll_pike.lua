-- THE TOLL PIKE: the Toll-Collector's own (data/characters/character_toll_collector.lua). A pike skewers two tiles
-- in a line, so a pair that stands one behind the other pays twice -- the spear family's line (docs/weapons.md), on
-- a body that does nothing else. The drop it gives up is the Collector's Pike, which reads the line the other way.
--
-- A demon's blow burns (docs/bestiary.md): `fire` is the element on a physical channel. Unstealable, on no shelf.
local Curve = require("models.curve")

return {
    name = "Toll Pike",
    description = "Skewers the two tiles directly in front of it.",
    flavor = "It is not collecting from you. It is collecting from the one behind you, through you.",
    sprite = "assets/items/weapon_toll_pike.png",
    type = "weapon",
    class = "creature",
    tags = { "spear", "pierce", "physical", "melee", "fire" },
    hands = 2,
    noSteal = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(8, 18),
        aoe = { shape = "line", length = 2 },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
            end
        end,
    },
}
