-- A lunging fang: the lamia's reach, and the bite that puts a string on you.
--
-- IT DOES NOT HOLD YOU. It decides that leaving costs. Coiled has no duration and no pin -- you may
-- walk anywhere on the board, and the board is what you are charged for (data/status/status_coiled.lua).
-- That is the whole difference from the knot at melee: one takes the turn, this takes the GROUND.
--
-- AND IT IS WHAT MAKES THE FLOCK WORSE. A harpy's gust drives a body a tile off whatever it was
-- standing next to; against an uncoiled company that is an inconvenience, and against a coiled one it
-- is the serpent's damage being delivered by somebody else's wings. Two bodies on one floor that make
-- each other worse is what a stratum is, and it is the reason this circle fields a second animal at
-- all rather than more harpies.
--
-- REACH 3, so the tether lands before the company is in the coils and the victim spends the approach
-- already owing. Slower than the knot: the lunge is a commitment.
--
-- NO FIRE, where the knot carries it. The tether is not a wound and the tag list should not claim it
-- is -- what this blow is FOR is the string, and the damage is the delivery.
--
-- THE COILER IS STAMPED ON THE INSTANCE, which is how the tether knows what to measure from -- the
-- same shape status_taunt stamps a taunter in, and read back the same way when the serpent falls.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

return {
    name = "Lunging Fang",
    description = "Strikes at reach and leaves Coiled.",
    flavor = "You will be allowed to go. That was never the part she was interested in.",
    sprite = "assets/items/lunging_fang.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "pierce", "physical", "ranged" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 5, -- slower than the knot's 3: the reach and the string are bought with tempo
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(4, 14),
        effect = function(fx)
            local dealt = fx.damage(fx.target)
            if dealt <= 0 or not fx.target.alive then return end
            local st = fx.applyStatus(fx.target, "status_coiled")
            if st then st.coiler = fx.user end -- what the tether measures from (see status_coiled)
        end,
    },
}
