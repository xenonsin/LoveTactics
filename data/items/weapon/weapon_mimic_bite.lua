-- A mimic's bite: the hinge, opened the wrong way.
--
-- PIERCE, not impact, and that is the whole read of the body. A coffer-crawler is a bag of loose metal
-- and a hammer makes it ring (data/items/weapon/weapon_coffer_shell.lua); this thing is a lid full of
-- teeth, and what it does is shut on an arm. The two are cousins -- both are containers that fight --
-- and they are told apart at the only place a player can feel the difference, which is the damage type
-- coming the other way.
--
-- THE HARDEST SINGLE BLOW AT ITS RUNG, and the stamina cost is why that is legal: 9 against the line
-- body's 6, so it cannot open its mouth every turn. An ambush is a thing that happens once and is then
-- answered, and a bite that landed every round would be a damage racer rather than a shock.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua). What the mimic fights with
-- BESIDES this is not authored anywhere -- it is whatever was in the chest (models/mimic.lua).
local Curve = require("models.curve")

return {
    name = "Mimic's Bite",
    description = "Shuts on an adjacent foe with the whole weight of the lid.",
    flavor = "The hinge is at the back, where a jaw's would be. Nobody looks at the back of a chest.",
    sprite = "assets/items/mimic_bite.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "pierce", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 9 },
        damage = Curve.ramp(14, 30),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
