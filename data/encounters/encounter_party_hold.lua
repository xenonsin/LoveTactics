-- HOLD AND LOOSE: an adventuring party ("The Rift's Adventurers", approved 2026-10-09). Written in
-- classes; each body's race is rolled when the party is fielded (models/adventurers.lua).
--
-- The Knight taunts and Halts the body it reaches, so it stands still. The Hunter marks and
-- cripples the held body from range. The Rogue's conditional strike lands its multiple on a body
-- that can't step away. Deeper, an Assassin finishes the held body and a Poacher Roots the next
-- one.
--
-- How you beat it: Don't take the fight where the knight puts you: go round it to the hunter, who
-- is fragile and doing the real damage.
local Adventurers = require("models.adventurers")

return Adventurers.party({
    id = "encounter_party_hold",
    name = "Hold and Loose",
    core = { "knight", "hunter", "rogue" },
    grow = { "fighter", "assassin", "poacher" },
    combo = "The Knight taunts and Halts the body it reaches, so it stands still. The Hunter marks and"
        .. " cripples the held body from range. The Rogue's conditional strike lands its multiple on a"
        .. " body that can't step away. Deeper, an Assassin finishes the held body and a Poacher Roots"
        .. " the next one.",
    counter = "Don't take the fight where the knight puts you: go round it to the hunter, who is fragile"
        .. " and doing the real damage.",
})
