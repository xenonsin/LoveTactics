-- WITHERING STAFF: the Pale Crone's own blow (data/characters/character_pale_crone.lua; "Envy's Bestiary", round 4).
-- Ovid's Envy walks with a staff wound in thorns, and the grass dies where she passes. A demon's blow burns -- a
-- physical blow with fire on it, never moved to the magical channel (tests/bestiary_spec.lua's demon rule).
local Curve = require("models.curve")

return {
    name = "Withering Staff",
    description = "Strikes an adjacent foe.",
    flavor = "Every thorn on it was a kindness once, done for somebody else.",
    sprite = "assets/items/weapon_withering_staff.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "impact", "physical", "fire", "melee" },
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
