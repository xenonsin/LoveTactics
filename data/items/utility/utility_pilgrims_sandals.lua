-- Pilgrim's Sandals: the road a pilgrim walks is consecrated by the walking. Every tile the wearer
-- steps OFF is left holding a short-lived Sanctuary (data/hazards/hazard_heal.lua) -- so the company
-- following in their footsteps mends as it advances -- and the wearer itself is mended by the walking,
-- through a Regeneration applied straight to it (`selfStatus`) and refreshed on every tile it crosses.
--
-- The self-heal used to be emergent rather than stated: the trail was laid UNDER the wearer, so the
-- tile it stopped on was a tile it had blessed, and standing in its own last print mended it for free.
-- That was elegant and it is gone, because a trail is now always laid behind (see Combat.layTrail) --
-- ground you leave, never ground you stand on. So the mending has to be said out loud. Two things are
-- worth knowing about the version that replaced it:
--
--   * it is NOT zone-bound. The old self-heal came from the hazard, so it carried the Sanctuary as its
--     `source` and Hazard.reap ended it the instant the wearer stepped off. This one is granted with no
--     source at all, so it ages on its own clock like a Regeneration from a potion -- which is why the
--     duration below is quoted rather than left to Regeneration's own 15.
--   * it therefore fades when the wearer STOPS, not when it moves. Refreshed per tile crossed, so a
--     pilgrim on the road keeps mending and a pilgrim standing still runs out. That is the same shape
--     the old behaviour had (a print faded under a wearer who stayed on it) arrived at by a different
--     road, and it is the more honest reading of the item: the walking is the sacrament.
--
-- The `trail` passive (models/item.lua, fired at the Combat.enterTile chokepoint) rather than a trait:
-- there is no reaction here, only ground left behind. `side` is the wearer's, so hazard_heal's
-- ally-only onEnter means a foe chasing the priest down their own path gains nothing from it.
--
-- The trail is deliberately briefer than a cast Sanctuary (10 ticks against 15): a spell that spends a
-- turn to hallow one tile must outlast footprints that cost nothing at all.
return {
    name = "Pilgrim's Sandals",
    description = "Every tile you leave is hallowed: your allies mend in your footsteps, and the walking mends you.",
    flavor = "The road is consecrated by the walking -- the only theology the Cathedral has never charged for.",
    sprite = "assets/items/pilgrims_sandals.png",
    type = "utility",
    tags = { "boots", "holy" },
    class = "priest",
    price = 520,
    repRank = 3,
    -- Far shorter-lived than a priest's cast Sanctuary (15): a footprint is a moment of hallowed
    -- ground, not a consecration, and the wearer paints one on EVERY tile it crosses. But ~2 turns
    -- rather than 2 ticks -- a print that faded inside half a turn was gone before anyone could stand
    -- in it, which is the whole point of the sandals.
    trail = {
        hazard = "hazard_heal", duration = 10,
        -- Matched to the print's own life, so a wearer that stops walking keeps mending for about as
        -- long as the last footprint it left behind would have lasted.
        selfStatus = { id = "status_regen", duration = 10 },
    },
}
