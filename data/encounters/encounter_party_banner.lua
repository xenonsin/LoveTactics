-- BANNER AND BEAST: an adventuring party ("The Rift's Adventurers", approved 2026-10-09). Written in
-- classes; each body's race is rolled when the party is fielded (models/adventurers.lua).
--
-- The Warlord plants banners whose auras stack. The Beastmaster's bonded beast and the Fighter
-- fight inside the field and hit far harder there. Deeper, a Druid in wolf shape and a Monk join
-- the pack inside the field.
--
-- How you beat it: Fight them outside the banner's field, or break the banner first. Pulled off the
-- field, the beasts are ordinary.
local Adventurers = require("models.adventurers")

return Adventurers.party({
    id = "encounter_party_banner",
    name = "Banner and Beast",
    core = { "warlord", "beastmaster", "fighter" },
    grow = { "hunter", "druid", "monk" },
    combo = "The Warlord plants banners whose auras stack. The Beastmaster's bonded beast and the Fighter"
        .. " fight inside the field and hit far harder there. Deeper, a Druid in wolf shape and a Monk"
        .. " join the pack inside the field.",
    counter = "Fight them outside the banner's field, or break the banner first. Pulled off the field, the"
        .. " beasts are ordinary.",
})
