-- The Cathedral's entry armor. Allies standing beside the wearer -- and the wearer -- mend a little
-- health every tick (trait_sanctified_presence).
--
-- The priest shelf has never sold armour, and the reason it can start here is that this is not a
-- defensive item at all: the vestments protect almost nothing, and what they do is turn the priest's
-- BODY into a zone. Lust's whole vocabulary is ground held open (docs/classes.md), and every other way
-- the Cathedral has said it -- a Sanctuary, an incense square, a hazard -- required spending a turn to
-- lay it down. This one is laid down by standing there.
--
-- One health a tick against the Unspent Heart's four, and the gap is right: this pays every adjacent
-- ally at once and cannot be switched off by hitting somebody. It is small on purpose because it is
-- unconditional, which is the rarest property a recovery in this game can have.
--
-- THE ONLY BOUGHT CARRIER OF THE PRESENCE, since the merge. The Cathedral used to sell this and
-- utility_grace_reliquary -- the same trait, the same tick, five ranks apart, one worn and one slotted --
-- which is a choice between two spellings rather than between two things. The reliquary was retired and
-- the vestments kept, because the armour is the version that costs something: a square of pace and a
-- chest slot, against a grid cell that was free to a priest with a spare one.
--
-- utility_hallowed_censer and utility_reliquary_kept_trust still grant the same presence from a grid
-- cell, so the slotted build survives -- it is quest stock now rather than shelf stock, which is the
-- right place for a second spelling. Stacking two sources does stack the healing, which is a legitimate
-- (expensive) build rather than an oversight.
--
-- Cloth, so it costs a square of pace: a priest whose aura is the item wants to be standing still.
local Curve = require("models.curve")

return {
    name = "Vestments of the Open Hand",
    description = "Allies adjacent to you, and you, heal a little each tick.",
    flavor = "The Cathedral cuts them without pockets. A hand that is holding something is not open.",
    sprite = "assets/items/armor_vestments_open_hand.png",
    type = "armor",
    tags = { "cloth", "holy" },
    class = "priest",
    price = 440,
    unlockQuests = 6,
    traits = { "trait_sanctified_presence" },
    bonus = { magicDefense = Curve.ramp(4, 14), defense = Curve.ramp(2, 12), movement = -1 },
    resist = { magical = 2 },
}
