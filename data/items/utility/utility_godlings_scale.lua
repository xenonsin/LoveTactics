-- THE GODLING'S SCALE: the Godling's own trophy. Round 2 (2026-09-25), "You are the dragon" -- picked over
-- "Bare Patch, reversed", on Keno's note on the round-1 trophy: "I don't like the per fight". So it is
-- always on, and nothing on it builds up or resets across a fight.
--
--   FIRE      it turns fire, as the hide it came off did
--   THE EYE   allies within 2 of the wearer gain +2 Damage, +1 Defense (trait_godlings_scale, a presence
--             turned round to reach the wearer's own side)
--   THE GOD   it carries trait_dragonkin, so to a hired kobold the wearer IS a dragon: it fights under its
--             own Dragon's Eye beside you, rallies when you are struck and breaks when you fall
--
-- A UTILITY, the warlord's: the house whose trade is making the line beside you fight harder. An
-- unstocked trophy (tests/discovery_spec.lua's named TROPHIES), found on Greed's seat.
local Curve = require("models.curve")

return {
    name = "Godling's Scale",
    description = "Resists fire. Allies within 2 of you gain damage and defense, and kobolds on your side treat you as their dragon.",
    flavor = "A single scale the size of a shield, and still warm. The kobolds who see it on you will not look away.",
    sprite = "assets/items/utility_godlings_scale.png",
    type = "utility",
    tags = { "trinket" },
    class = "warlord",
    unlockLevel = 6,
    unstocked = true,
    traits = { "trait_godlings_scale", "trait_dragonkin" },
    resist = { fire = Curve.ramp(2, 12) },
}
