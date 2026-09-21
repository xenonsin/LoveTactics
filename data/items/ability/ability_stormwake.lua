-- Stormwake: the charge goes into the water and finds everybody standing in it.
--
-- The Tidecaller's second half, and the reason the Mere fights where it fights. A lightning cast is
-- already the one element in this game that reads the GROUND -- Combat.conductLightning arcs it into
-- every adjacent cell carrying the `conductable` tag, and a fen board is mire, shallows and deep water,
-- all three of which carry it. So this is a body that turns the floor into the weapon, and it needed no
-- new machinery whatsoever to do it: the conduction has been in the engine since long before the fen.
--
-- AND THE ANSWER TO IT IS THE SAME FACT. A naga takes lightning at -4 (data/races/naga.lua), and a
-- naga pack sharing one channel is a naga pack sharing one conductor. The player's own Jolt does to the
-- Mere exactly what this does to the company -- more, because the race is standing in it on purpose.
-- That is the shape every good enemy mechanic in this game has: it teaches the board's rule by using
-- it, and the answer to it is the rule.
local Curve = require("models.curve")

return {
    name = "Stormwake",
    description = "A charge through the water. Arcs into every wet or conducting tile it touches.",
    flavor = "She does not aim it at you. She aims it at the water you are standing in.",
    sprite = "assets/items/stormwake.png",
    type = "ability",
    tags = { "lightning", "magical" },
    class = "mage",
    dropOnly = true,
    -- HAND-PLACED, and `. drop-tier` says 1. The damage curve is the small half of this cast; the
    -- half that matters is the arc, and Combat.conductLightning is engine rather than an authored
    -- magnitude, so the grader sees a cheap bolt and none of what makes it the Tidecaller's fight.
    -- The same blindness the Wrap carries, for the same reason, written down in both files.
    unlockLevel = 7,
    activeAbility = {
        target = "enemy",
        range = 4,
        speed = 5,
        cost = { stat = "mana", amount = 10 },
        damage = Curve.ramp(12, 24),
        -- The arc is the engine's own: a `lightning` blow conducts out of the struck cell into every
        -- adjacent conducting tile (Combat.conductLightning), which is why nothing here has to know
        -- what the board is made of.
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
