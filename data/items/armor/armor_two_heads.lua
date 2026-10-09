-- TWO HEADS: one of the Lernaean Hydra's three trophies, on the Barbarian's shelf. Approved 2026-10-09 ("The
-- Crown's Bestiary", slice E). The hydra's regrowth worn as a hide: cut the wearer and it comes back with more
-- mouths -- each slash blow that strikes it banks one more strike on its next weapon attack, up to 3
-- (trait_two_heads, status_two_heads, models/lerna.lua).
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
local Curve = require("models.curve")

return {
    name = "Two Heads",
    description = "Each time a slash blow strikes you, your next attack strikes one more time (up to 3).",
    flavor = "Two of the necks are stitched in at the collar. Nobody stitched them in.",
    sprite = "assets/items/armor_two_heads.png",
    type = "armor",
    tags = { "hide" },
    class = "barbarian",
    unlockLevel = 15,
    unstocked = true,
    traits = { "trait_two_heads" },
    bonus = { defense = Curve.ramp(4, 14), movement = -1 },
}
