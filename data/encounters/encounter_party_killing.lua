-- THE KILLING GROUND: an adventuring party ("The Rift's Adventurers", approved 2026-10-09). Written in
-- classes; each body's race is rolled when the party is fielded (models/adventurers.lua).
--
-- The Artificer sets turrets that cover a trapped lane. The Trapper fills it. The Knight taunts and
-- Halts you inside it. Grows with a Hunter, a Bulwark to push you in, and a Poacher for whatever is
-- Rooted.
--
-- How you beat it: Don't take the lane. Come round the side, and break the turrets before you
-- engage.
local Adventurers = require("models.adventurers")

return Adventurers.party({
    id = "encounter_party_killing",
    name = "The Killing Ground",
    core = { "artificer", "trapper", "knight" },
    grow = { "hunter", "bulwark", "poacher" },
})
