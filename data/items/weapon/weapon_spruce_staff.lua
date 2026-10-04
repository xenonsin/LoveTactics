-- SPRUCE STAFF: the Old Spruce's trophy (data/characters/character_old_spruce.lua), on the Druid's shelf. Approved
-- on "Sloth's Bestiary" (2026-10-04). Each turn the bearer attacks nothing, a root rises on an empty tile beside it,
-- and nothing crosses a root (trait_spruce_staff, data/walls/roots.lua).
--
-- A STAFF BY CONTRACT (docs/weapons.md): Wait becomes Focus, and the strike is a feeble afterthought. The two halves
-- are one habit here -- a Focus is a turn that attacks nothing, so the staff's own swap is what grows the wood.
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
local Curve = require("models.curve")

return {
    name = "Spruce Staff",
    description = "Replaces Wait with Focus. Each turn you attack nothing, a root rises beside you. Foes cannot cross Roots.",
    flavor = "Cut from a tree that was still arguing about it.",
    sprite = "assets/items/weapon_spruce_staff.png",
    type = "weapon",
    tags = { "staff", "magical", "melee" },
    class = "druid",
    unlockLevel = 10,
    unstocked = true,
    waitBehavior = { kind = "focus", mana = Curve.ramp(9, 19), speed = 10 },
    traits = { "trait_spruce_staff" },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(11, 21), -- feeble, as every staff's strike is
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
