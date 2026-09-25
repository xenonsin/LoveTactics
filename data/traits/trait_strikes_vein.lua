-- STRIKES THE VEIN: the golems' own half of Delve (round 2's call -- the golems carry the Delver's
-- ability_delve, and what is theirs alone is the vein). A flag, read by ability_delve's effect: when a
-- bearer surfaces, the hole it sank through becomes a coin heap, or one time in three a lava pit
-- (models/golem.lua, Golem.strikeVein) -- and a bearer never brings the Delver's cave-in.
return {
    name = "Strikes the Vein",
    description = "Where it delves, the hole it leaves is gold, or sometimes lava.",
    strikesVein = true,
}
