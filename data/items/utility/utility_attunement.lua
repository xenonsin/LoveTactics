-- Attunement: a wider channel for the arcane. A passive charm that raises the bearer's maximum mana
-- (`maxBonus.mana`, folded into Combat.unreservedMax). Mana persists between battles and does not
-- refill, so like Toughness this lifts the ceiling as headroom -- room to bank more mana (via Focus or
-- an Arcane Reservoir) and hold a bigger reserve for the spells that need it.
local Curve = require("models.curve")

return {
    name = "Attunement",
    description = "Raises your maximum mana.",
    flavor = "A wider channel. The Arcanum measures a mage by what they can hold, not by what they throw.",
    sprite = "assets/items/attunement.png",
    type = "utility",
    tags = { "charm" },
    class = "mage",
    unlockQuests = 2,
    dropTier = 2,
    maxBonus = { mana = Curve.ramp(12) },
    -- a deeper pool is more castings
    bonus = { magicDamage = 1 },
}
