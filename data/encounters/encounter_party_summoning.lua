-- THE SUMMONING: an adventuring party ("The Rift's Adventurers", approved 2026-10-09). Written in
-- classes; each body's race is rolled when the party is fielded (models/adventurers.lua).
--
-- The Summoner banks mana and fields elementals. The Warlord's banners make them hit harder. The
-- Elementalist's sigils reshape the summoning spell. Deeper, a Shaman's spirits fight beside the
-- elementals and on floor 13 a Totemist's field cancels your spells.
--
-- How you beat it: Kill the summoner and the elementals stop coming. Fight off the banner, and
-- bring an exorcist to Banish them.
local Adventurers = require("models.adventurers")

return Adventurers.party({
    id = "encounter_party_summoning",
    name = "The Summoning",
    core = { "summoner", "warlord", "elementalist" },
    grow = { "shaman", "knight", "totemist" },
    combo = "The Summoner banks mana and fields elementals. The Warlord's banners make them hit harder."
        .. " The Elementalist's sigils reshape the summoning spell. Deeper, a Shaman's spirits fight"
        .. " beside the elementals and on floor 13 a Totemist's field cancels your spells.",
    counter = "Kill the summoner and the elementals stop coming. Fight off the banner, and bring an"
        .. " exorcist to Banish them.",
})
