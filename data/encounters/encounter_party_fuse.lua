-- THE FUSE: an adventuring party ("The Rift's Adventurers", approved 2026-10-09). Written in
-- classes; each body's race is rolled when the party is fielded (models/adventurers.lua).
--
-- The Saboteur plants charges you can't see and sets them off when you're standing on one. The
-- Bombardier's blasts set off any charge nearby. The Artificer's turrets keep you from crossing
-- quickly. Grows with a Bulwark to push you onto the charges, a Trapper and a Hunter.
--
-- How you beat it: Kill the saboteur before he picks his moment, and keep your bodies spread so one
-- blast takes one of them.
local Adventurers = require("models.adventurers")

return Adventurers.party({
    id = "encounter_party_fuse",
    name = "The Fuse",
    core = { "saboteur", "bombardier", "artificer" },
    grow = { "bulwark", "trapper", "hunter" },
    combo = "The Saboteur plants charges you can't see and sets them off when you're standing on one. The"
        .. " Bombardier's blasts set off any charge nearby. The Artificer's turrets keep you from"
        .. " crossing quickly. Grows with a Bulwark to push you onto the charges, a Trapper and a Hunter.",
    counter = "Kill the saboteur before he picks his moment, and keep your bodies spread so one blast takes"
        .. " one of them.",
})
