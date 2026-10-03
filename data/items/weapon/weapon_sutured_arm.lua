-- SUTURED ARM: the Patchwork's own blow (data/characters/character_patchwork.lua; "Envy's Bestiary", round 1). An
-- arm that was somebody else's, swung like a club, because the joint was sewn on the wrong way round.
local Curve = require("models.curve")

return {
    name = "Sutured Arm",
    description = "Clubs an adjacent foe.",
    flavor = "Three different people's knuckles, and none of them agree about which way a fist closes.",
    sprite = "assets/items/weapon_sutured_arm.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "impact", "physical", "melee" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 7 },
        damage = Curve.ramp(12, 22),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
