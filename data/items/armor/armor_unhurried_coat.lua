    -- UNHURRIED COAT: what comes off a rime slime (data/characters/character_rime_slime.lua). The answer to
-- its own Torpor, and to every Stun (a named statusImmunity -- the Silk Lining's shape).
    --
    -- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
    local Curve = require("models.curve")

return {
        name = "Unhurried Coat",
        description = "You can't be Stunned or made Torpid.",
        flavor = "Whatever it is, it can wait.",
        sprite = "assets/items/armor_unhurried_coat.png",
        type = "armor",
        class = "knight",
        unlockLevel = 9,
        unstocked = true,
        tags = { "cloth" },
    bonus = { defense = Curve.ramp(3, 13), movement = -1 },
    statusImmunity = { "status_torpid", "status_stun" },
    }
