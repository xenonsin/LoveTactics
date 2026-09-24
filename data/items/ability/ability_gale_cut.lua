-- GALE CUT: the Wyvern's Wind Shear, rebuilt for a person. A cut of wind at two or three tiles -- slash and
-- wind at once -- and then you step a tile back (fx.retreat). No bow needed, and it cannot be thrown at
-- anything already beside you: hit, and stay out of reach, which is the whole of how a wyvern lives.
--
-- On the Hunter's shelf, the Lodge's root: the house this circle pays into, and the house that already
-- fights from the edge of reach.
local Curve = require("models.curve")

return {
    name = "Gale Cut",
    description = "Cuts a foe two or three tiles away with the wind, then steps back a tile. Cannot reach an adjacent foe.",
    flavor = "The trick is not the cut. The trick is being somewhere else when they come to answer it.",
    sprite = "assets/items/ability_gale_cut.png",
    type = "ability",
    tags = { "wind", "slash", "physical", "ranged" },
    class = "hunter",
    unlockLevel = 3,
    unstocked = true,
    activeAbility = {
        target = "enemy",
        range = 3,
        minRange = 2,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(8, 18),
        effect = function(fx)
            fx.damage(fx.target)
            if fx.user.alive and fx.target then fx.retreat(fx.target, 1) end
        end,
    },
}
