-- THE PURGE: an adventuring party ("The Rift's Adventurers", approved 2026-10-09). Written in
-- classes; each body's race is rolled when the party is fielded (models/adventurers.lua).
--
-- The Inquisitor's Mark of Heresy strips one of yours of every blessing. The Crusader's holy blows
-- heal him on a kill. The Assassin finishes the marked body when it drops under half. Deeper, an
-- Exorcist strips the rest, a Duelist locks onto the marked one and a Paladin shields the line.
--
-- How you beat it: When one of yours is marked, pull them back. Kill the inquisitor and there's
-- nothing to pile onto.
local Adventurers = require("models.adventurers")

return Adventurers.party({
    id = "encounter_party_purge",
    name = "The Purge",
    core = { "inquisitor", "crusader", "assassin" },
    grow = { "exorcist", "duelist", "paladin" },
    combo = "The Inquisitor's Mark of Heresy strips one of yours of every blessing. The Crusader's holy"
        .. " blows heal him on a kill. The Assassin finishes the marked body when it drops under half."
        .. " Deeper, an Exorcist strips the rest, a Duelist locks onto the marked one and a Paladin"
        .. " shields the line.",
    counter = "When one of yours is marked, pull them back. Kill the inquisitor and there's nothing to pile"
        .. " onto.",
})
