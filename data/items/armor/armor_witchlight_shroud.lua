-- Quest-only: `class` with no `price` (docs/classes.md).
--
-- Carries a square of Witchlight (`incense`, Combat.layIncense): nothing standing in it can hide from
-- being targeted (status_limned).
--
-- The exact counter to the rogue's half of this file. Invisible, Vanishing Act, the Unlit Hood, a
-- Stillshade ambush -- every one of them works by not being a legal target, and Limned makes the unit
-- targetable however well it is hidden. A shroud-wearer walking into the tile an assassin vanished
-- from simply turns them back on.
--
-- And it is the ONLY answer to concealment in the catalog that does not require guessing the tile,
-- because it is a square rather than a cast. That is what the armour slot buys here: the mage stops
-- spending turns looking.
--
-- Unsided, which is the cost and is not small -- the party's own rogue is lit up standing beside the
-- mage wearing it. A stealth build and this in the same company is a contradiction, and the player
-- should feel that as a loadout decision rather than read it in a tooltip.
--
-- Cloth: a square of pace.
local Curve = require("models.curve")

return {
    name = "Witchlight Shroud",
    description = "Inflicts Limned on adjacent foes.",
    flavor = "The Arcanum lights its own corridors with it, which tells you what it was built to find.",
    sprite = "assets/items/armor_witchlight_shroud.png",
    type = "armor",
    tags = { "cloth", "light" },
    class = "mage",
    dropTier = 5,
    incense = { hazard = "hazard_witchlight", radius = 1 },
    bonus = { magicDefense = Curve.ramp(4, 14), movement = -1 },
}
