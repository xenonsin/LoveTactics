-- Outrider's Harness: the fighter half of the Skirmisher (fighter x hunter). Ride two tiles or more
-- into a blow and nothing can answer it.
--
-- The item rule R1 was written for. It was drafted with "+1 movement, and the first post-move strike
-- Exposes" -- and the movement half is exactly what the armour spread's tiers exist to price, so a piece
-- that hands a square back is not a bonus, it is a hole in the cost table (docs/classes.md). The rule
-- now says no armour grants movement, full stop, and this is where it was written down.
--
-- What it took instead is the better item. A skirmisher's real problem was never pace, it was that
-- riding into a line means riding into everything the line can throw back -- and this shelf's entire
-- pitch is that you go in and come out. Unanswerable strikes make the going-in free; Harrying Strike
-- and the Harrier's Bow are what make the coming-out possible.
--
-- It pays its square like everything else on the rack. The 0 tier this was once filed under is gone:
-- every coat costs pace now, and a skirmisher's answer to that is the same as its answer to
-- everything, which is to be somewhere else by the time it matters.
local Curve = require("models.curve")

return {
    name = "Outrider's Harness",
    description = "If you have moved two tiles or more this turn, your attacks cannot be countered.",
    flavor = "Nobody in the column is armoured for a fight. They are armoured for a departure.",
    sprite = "assets/items/armor_outriders_harness.png",
    type = "armor",
    tags = { "leather" },
    class = "skirmisher",
    unlockQuests = 6,
    dropTier = 5,
    bonus = { defense = Curve.ramp(3, 13), movement = -1 },
    traits = { "trait_outriders_harness" },
}
