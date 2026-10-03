-- EEL-SKIN BOOTS: the Sand-Eels' trophy (data/characters/character_sand_eel.lua), on the Skirmisher's shelf.
-- Approved on "Envy's Bestiary", round 3. The brood swims the sand the company sinks in, and its hide keeps the
-- wearer up: Quicksand does not Mire you -- a named immunity to the one status the sand lays (`statusImmunity`).
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
local Curve = require("models.curve")

return {
    name = "Eel-Skin Boots",
    description = "Quicksand does not Mire you.",
    flavor = "Slick on the outside, dry on the inside, and they leave no print a thing below could follow.",
    sprite = "assets/items/armor_eel_skin_boots.png",
    type = "armor",
    tags = { "leather" },
    class = "skirmisher",
    unlockLevel = 11,
    unstocked = true,
    statusImmunity = { "status_mired" },
    bonus = { defense = Curve.ramp(3, 13), movement = -1 },
}
