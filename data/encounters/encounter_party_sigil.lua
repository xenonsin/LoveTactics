-- THE SIGIL CHOIR: an adventuring party ("The Rift's Adventurers", approved 2026-10-09). Written in
-- classes; each body's race is rolled when the party is fielded (models/adventurers.lua).
--
-- The Elementalist lays sigils that reshape any spell cast beside them. The Mage casts from a sigil
-- and the spell comes out twinned or farther. The Priest heals from one, so the heal lands twice.
-- Deeper, a Knight holds the front, a Summoner calls through the sigils, and on floor 15 a Theurge
-- grows her spell on one.
--
-- How you beat it: Kill the elementalist, or step onto a sigil yourself so they can't use it.
-- Without the sigils they are ordinary casters.
local Adventurers = require("models.adventurers")

return Adventurers.party({
    id = "encounter_party_sigil",
    name = "The Sigil Choir",
    core = { "elementalist", "mage", "priest" },
    grow = { "knight", "summoner", "theurge" },
    combo = "The Elementalist lays sigils that reshape any spell cast beside them. The Mage casts from a"
        .. " sigil and the spell comes out twinned or farther. The Priest heals from one, so the heal"
        .. " lands twice. Deeper, a Knight holds the front, a Summoner calls through the sigils, and on"
        .. " floor 15 a Theurge grows her spell on one.",
    counter = "Kill the elementalist, or step onto a sigil yourself so they can't use it. Without the"
        .. " sigils they are ordinary casters.",
})
