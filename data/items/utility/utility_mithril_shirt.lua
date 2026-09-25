-- MITHRIL SHIRT: the Hoard-Thane's own trophy (round 3, 2026-09-24). Every dwarf hall owes one mithril
-- coat -- the one that turned the troll's spear in Moria. NO BLOW AGAINST ITS WEARER IS EVER A CRITICAL
-- (`critProof`, trait_mithril): a rolled critical and a forced one (a Pounce from hiding) both land as
-- ordinary hits.
--
-- The round-3 pitch turned only the FIRST critical each fight; Keno approved it with "needs a buff", and
-- the buff is that it turns every one.
--
-- A UTILITY, NOT AN ARMOR, and that is the only way to keep the pitch's other promise. It was pitched as
-- costing no movement, and every armor in the game costs at least a square (docs/classes.md, held by
-- tests/armor_spec.lua) -- so it is worn under the coat, the way Bilbo wore it, and takes a utility cell.
--
-- An unstocked trophy: on the rack, never sold (tests/discovery_spec.lua's named TROPHIES). Knight's
-- shelf, as the piece that armours the body.
local Curve = require("models.curve")

return {
    name = "Mithril Shirt",
    description = "Raises defense. No blow against you is ever a critical.",
    flavor = "Light as a feather, and hard as dragon-scales. Worth more than the Shire and everything in it.",
    sprite = "assets/items/utility_mithril_shirt.png",
    type = "utility",
    tags = { "trinket" },
    class = "knight",
    unlockLevel = 6,
    unstocked = true,
    traits = { "trait_mithril" },
    bonus = { defense = Curve.ramp(2, 12) },
}
