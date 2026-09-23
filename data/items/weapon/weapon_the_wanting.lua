-- THE WANTING: the Matriarch's cry, and the Lust circle's fire stated as a sentence about distance.
--
-- SHE DOES NOT MOVE YOU. SHE MAKES YOU COME. Everything else on this stratum is displacement -- the
-- flock hauls a body in with its talons and drives one off with a gust, and a company fights the whole
-- floor being pushed around like furniture. She is the one body that does not touch you at all: the
-- cry takes the victim's own turn away and points it at her, and the burn runs the entire time it is
-- walking. Burning desire is the theme and this is the arithmetic of it -- **wanting her costs health
-- per turn, and the wanting is not optional.**
--
-- SO SHE IS AN ESCALATION IN KIND AND NOT IN SIZE, which is what separates an alpha from a bigger
-- chaff. The flock decides where your body is; she decides what it does.
--
-- IT USED TO PULL, AND THE PULL WAS A WORKAROUND. `status_taunt` was enforced in models/ai.lua's enemy
-- planner and nowhere else, so a taunt landed on a party member was a badge the player read and
-- ignored -- and a cry that compels the company could not be built out of it. Dragging the body was the
-- nearest honest substitute. The compulsion binds a player-controlled unit now (see
-- data/status/status_taunt.lua, which took the seizure into the status the way Charm holds its own
-- flip), so the cry is the thing it was always written to be and the drag went back to the flock,
-- whose verb it is.
--
-- THE TAUNTER IS STAMPED ON THE INSTANCE, which is how the compulsion knows where to send the victim.
-- The status defaults it from the applier now, so this line is belt and braces rather than the load-
-- bearing one it used to be -- and it is kept because reading `st.taunter = fx.user` at the delivery
-- is how every other deliverer in the game says who the jeer belongs to.
--
-- FIRE AND MAGICAL, where the flock's two weapons are physical. The circle otherwise runs entirely on
-- armour, so a party in plate would walk through the whole stratum without ever looking at a resist
-- (the same complaint weapon_briar_lash was authored against, from the other side). Her cry is the one
-- blow on this ground that asks what the company is wearing underneath.
--
-- BOTH RIDERS ARE GATED ON THE HIT. A rider that could not miss riding a blow that could is the shape
-- of bug the whole circle was rebuilt out of once already (docs/accuracy.md).
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

return {
    name = "The Wanting",
    description = "Calls a distant foe and leaves Taunt and Burn.",
    flavor = "Every anointed child was told the Light would call them by name. Something did.",
    sprite = "assets/items/the_wanting.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "fire", "magical", "ranged" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 4,
        requiresSight = true,
        speed = 6,
        cost = { stat = "mana", amount = 8 },
        damage = Curve.ramp(8, 18),
        effect = function(fx)
            local dealt = fx.damage(fx.target)
            if dealt <= 0 or not fx.target.alive then return end
            local st = fx.applyStatus(fx.target, "status_taunt")
            if st then st.taunter = fx.user end -- who the cry drags them toward (see ability_shout)
            fx.applyStatus(fx.target, "status_burn")
        end,
    },
}
