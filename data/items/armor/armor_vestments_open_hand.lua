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
-- utility_grace_reliquary and utility_hallowed_censer both grant the same presence from a grid cell.
-- The vestments are for a priest whose nine cells are already spoken for -- and stacking two sources
-- does stack the healing, which is a legitimate (expensive) build rather than an oversight.
--
-- Cloth, so it costs a square of pace: a priest whose aura is the item wants to be standing still.
return {
    name = "Vestments of the Open Hand",
    description = "Allies adjacent to you, and you, mend a little health each tick.",
    flavor = "The Cathedral cuts them without pockets. A hand that is holding something is not open.",
    sprite = "assets/items/armor_vestments_open_hand.png",
    type = "armor",
    tags = { "cloth", "holy" },
    class = "priest",
    price = 300,
    repRank = 2,
    traits = { "trait_sanctified_presence" },
    bonus = { magicDefense = { 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9 }, defense = { 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4 }, movement = -1 },
    resist = { magical = { 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4 } },
}
