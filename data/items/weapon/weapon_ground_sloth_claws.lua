-- GROUND SLOTH CLAWS: the Ground Sloth's own blow (data/characters/character_ground_sloth.lua). Approved
-- 2026-10-04 on "Sloth's Bestiary", slice A: "its next turn swings once per banked turn and once more for the turn
-- itself."
--
-- The bank is read off the badge BEFORE the first landing (models/sloth_beasts.lua, SlothBeasts.swings) and
-- spent through fx.clearStatus, which both damage previews hold inert -- so a hover quotes the flurry and spends
-- nothing. Each landing is its own fx.damage: its own hit roll, its own armour, as the brave rule's are.
--
-- A natural weapon: never sold, never stolen. What the company carries off is Sleeper's Claws.
local Curve = require("models.curve")

return {
    name = "Ground Sloth Claws",
    description = "Rakes an adjacent foe once, and once more for each turn banked.",
    flavor = "Hooks for pulling down branches, which it has decided you are.",
    sprite = "assets/items/weapon_ground_sloth_claws.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "slash", "physical", "melee" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 6, -- it is a sloth
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(6, 16),
        effect = function(fx)
            local swings = require("models.sloth_beasts").swings(fx.user)
            if swings > 1 then fx.clearStatus(fx.user, "status_banked") end
            for _ = 1, swings do
                if fx.target and fx.target.alive then fx.damage(fx.target) end
            end
        end,
    },
}
