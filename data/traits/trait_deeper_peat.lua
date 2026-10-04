-- DEEPER PEAT: the Cairn-Keeper's (utility_deeper_peat; "Sloth's Bestiary", 2026-10-04, slice C). Within 3 of it,
-- the Bog-Bound's rule is doubled: a threshold of 16, and a 4-movement toll. The Keeper stands in its own reach.
--
-- A FLAG with its reach as the value, read by models/sloth_bog.lua's `deeper` through Trait.flag -- so a Keeper
-- that is Sundered stops deepening anything, which is "break the Cairn-Keeper" in the counter's own words.
return {
    name = "Deeper Peat",
    description = "Within 3 of you, the Bog-Bound's rule is doubled: a threshold of 16, and a 4-movement toll.",
    deeperPeat = 3,
    notAReaction = true,
}
