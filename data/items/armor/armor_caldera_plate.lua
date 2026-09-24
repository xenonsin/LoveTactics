    -- CALDERA PLATE: one of the Caldera King's own (data/characters/character_caldera_king.lua). His
-- eruption, worn -- once a battle, at the edge of falling (trait_caldera_plate).
    --
    -- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
    local Curve = require("models.curve")

return {
        name = "Caldera Plate",
        description = "Once per battle, dropping below half health burns every adjacent foe.",
        flavor = "Forged in the thing that forged it.",
        sprite = "assets/items/armor_caldera_plate.png",
        type = "armor",
        class = "fighter",
        unlockLevel = 8,
        unstocked = true,
        tags = { "hide", "fire" },
    bonus = { defense = Curve.ramp(3, 13), movement = -1 },
    traits = { "trait_caldera_plate" },
    }
