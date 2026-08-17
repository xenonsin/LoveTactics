-- Underbite: the wyrm form's natural weapon (data/characters/character_wild_wyrm.lua). It does not
-- reach across the ground -- it comes up through it, which is why a blow that lands also pins.
--
-- THE FORM'S THESIS IN ONE SWING. The other three Wild Shapes all fight on the surface: the wolf and
-- the bear close, the raven keeps away. This one arrives from underneath, and the Root it leaves is
-- that arrival stated mechanically -- something that has just been bitten from below is standing in a
-- hole. It is also what makes the form's other two abilities work: Tunnel repositions freely and Old
-- Breath is a cone, and both want their targets where they were left.
--
-- Range 1 and no dead zone, unlike the raven's Flung Quills: a wyrm has no minimum distance because
-- it was never throwing anything.
--
-- `natural`, `noSteal`, sold by nobody: a creature's body is not loot (models/item.lua), which is also
-- what keeps it out of any weapon family's roster of five (tests/weapon_spec.lua).
local Curve = require("models.curve")

return {
    name = "Underbite",
    description = "Surfaces beneath a foe, and leaves it Rooted.",
    flavor = "The ground gives once. By the time it gives twice you are already in it.",
    sprite = "assets/items/underbite.png",
    type = "weapon",
    tags = { "natural", "pierce", "physical" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 5,
        cost = { stat = "stamina", amount = 5 },
        --        level:  0  1  2  3  4  5  6  7   8   9  10
        damage = Curve.ramp(11, 23),
        effect = function(fx)
            fx.damage(fx.target)
            -- Applied after the blow so a body the bite kills is not briefly pinned on its way down.
            fx.applyStatus(fx.target, "status_root")
        end,
    },
}
