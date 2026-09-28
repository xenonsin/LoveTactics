-- DOUSED: a Blaze put out by water (models/storm.lua; "Fire, Lightning, and Dirty Thunder", 2026-09-27). A water
-- cast that lands on it, or rain it stands in, and for two turns it is only a body: no Wildfire, no kindled ground,
-- no mending on the flows, and its fists strike without fire. The company's own answer to the thing, carried.
return {
    name = "Doused",
    abbr = "Dsd",
    description = "Put out: no Wildfire, no burning blows, no healing in lava.",
    color = { 0.300, 0.470, 0.640 }, -- badge tint (water)
    duration = 10, -- two turns at Status.TICKS_PER_TURN
    debuff = true,
}
