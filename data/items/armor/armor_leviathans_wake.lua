-- LEVIATHAN'S WAKE: what the serpent leaves behind it, cut into a vanguard's coat (data/characters/
-- character_leviathan.lua; "Envy's Bestiary", row lv_drops, approved word for word). Every tile you leave is
-- quicksand until your next turn.
--
-- A TRAIL, the Cinderstride Boots' and the Thing Under the Seam's mechanism (Combat.layTrail): laid behind, never
-- underfoot, so the wearer never Mires itself. Five ticks is one turn at Status.TICKS_PER_TURN -- "until your
-- next turn". The Vanguard decides where somebody else stands; this decides where they cannot walk after you.
--
-- Hide over scale: a square of pace, as every coat costs (tests/armor_spec.lua). An unstocked trophy on the
-- approach's rung, noSteal like every stair piece.
local Curve = require("models.curve")

return {
    name = "Leviathan's Wake",
    description = "Tiles you leave become quicksand until your next turn.",
    flavor = "Whatever walked here last, the ground has not finished swallowing it.",
    sprite = "assets/items/armor_leviathans_wake.png",
    type = "armor",
    tags = { "hide" },
    class = "vanguard",
    unlockLevel = 11,
    unstocked = true,
    noSteal = true,
    bonus = { defense = Curve.ramp(5, 15), movement = -1 },
    trail = { hazard = "hazard_quicksand", duration = 5 },
}
