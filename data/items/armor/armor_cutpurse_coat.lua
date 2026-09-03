-- Quest-only: `class` with no `price` (docs/classes.md). The Undercroft does not sell this one; it is
-- what you are given once they have decided about you.
--
-- Armor whose stat line is your INCOME. trait_skimmers_cut lifts a little coin off every living foe
-- the wearer lands a blow on, paid out with the spoils -- so the coat's real number never appears on
-- the tooltip and is not a combat number at all. It is the greed shelf's thesis worn on the body: the
-- fight is a place where money is, and a rogue who wins slowly earns more than one who wins fast.
--
-- Deliberately thin steel. A wearer who is being hit is not landing blows, and a coat that made them
-- durable enough to trade would be paying them for the wrong behaviour.
local Curve = require("models.curve")

return {
    name = "Cutpurse's Coat",
    description = "On damage dealt: gain gold.",
    flavor = "The lining is all pockets. The Undercroft charges apprentices for the tailoring and nothing for the lesson.",
    sprite = "assets/items/armor_cutpurse_coat.png",
    type = "armor",
    tags = { "leather" },
    dropTier = 2,
    -- Tagged for identity and growth, never for the rack: quest-only gear carries the discipline but
    -- has no price, so it is not part of what the shelf unlock delivers (tests/class_ladder_spec.lua).
    class = "mammonite",
    traits = { "trait_skimmers_cut" },
    bonus = { defense = Curve.ramp(3, 13), movement = -1 },
}
