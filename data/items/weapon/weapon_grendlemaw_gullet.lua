-- The Grendlemaw's gullet: it swallows a body whole, and the body is simply gone until it is cut out.
--
-- Built on status_suspended, which already does exactly this and does it honestly: the swallowed unit
-- cannot act, cannot answer, cannot move, cannot be aimed at, and comes back a long way down the turn
-- order. Nothing new had to be invented -- the one control in the game that removes a body in BOTH
-- directions is the right reading of being eaten.
--
-- And that dual edge is what keeps this fair rather than merely nasty. A swallowed body is protected
-- from everything else on the board while it hangs, so the Grendlemaw eating your knight is not a free
-- kill -- it is a party of three for a while, which on a mire board where crossing is already expensive
-- is quite enough of a problem. The counterplay is to kill the maw, which shortens nothing and threatens
-- nothing else in the meantime.
--
-- Aimed at reach 1, so it has to close. A mythic body that could swallow across the board would have no
-- answer at all; this one has an obvious one -- do not stand next to it.
local Curve = require("models.curve")

return {
    name = "Gullet",
    description = "Bites an adjacent foe and leaves Suspended.",
    flavor = "The fen has one bad idea and has been having it for a very long time.",
    sprite = "assets/items/grendlemaw_gullet.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "bite", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 6, -- slow: the whole turn, and telegraphed by how long it takes to come round
        cost = { stat = "stamina", amount = 10 },
        damage = Curve.ramp(10, 20),
        effect = function(fx)
            fx.damage(fx.target)
            fx.applyStatus(fx.target, "status_suspended")
        end,
    },
}
