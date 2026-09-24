    -- ABOVE REPROACH: one of the Apex Crystal's own (data/characters/character_apex_crystal.lua). Its ward,
-- worn: the fight opens with a one-charge barrier against anything (status_above_reproach).
    --
    -- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
    local Curve = require("models.curve")

return {
        name = "Above Reproach",
        description = "The first hit on you each battle deals nothing.",
        flavor = "Nothing has ever quite reached it.",
        sprite = "assets/items/armor_above_reproach.png",
        type = "armor",
        class = "mage",
        unlockLevel = 14,
        unstocked = true,
        tags = { "cloth" },
    bonus = { defense = Curve.ramp(2, 12), movement = -1 },
    openingBoon = { id = "status_above_reproach" },
    }
