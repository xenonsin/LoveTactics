-- HIBERNAL HIDE: the Old Sloth's trophy (data/characters/character_old_sloth.lua), on the Warden's shelf. Approved
-- 2026-10-04 on "Sloth's Bestiary", slice A. The sloth's sleep worn as a coat: the blow that wakes you lands at
-- half, and you wake swinging (trait_hibernal_hide).
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
local Curve = require("models.curve")

return {
    name = "Hibernal Hide",
    description = "Blows that wake you from Sleep deal half. Your first blow after waking deals 50% more.",
    flavor = "Thick enough to sleep through a winter in. It has opinions about being woken.",
    sprite = "assets/items/armor_hibernal_hide.png",
    type = "armor",
    tags = { "hide" },
    class = "warden",
    unlockLevel = 9,
    unstocked = true,
    traits = { "trait_hibernal_hide" },
    bonus = { defense = Curve.ramp(4, 14), movement = -1 },
}
