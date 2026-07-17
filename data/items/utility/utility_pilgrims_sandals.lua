-- Pilgrim's Sandals: the road a pilgrim walks is consecrated by the walking. Every tile the wearer
-- crosses is left holding a short-lived Sanctuary (data/hazards/hazard_heal.lua) -- so the company
-- following in their footsteps mends as it advances, and the wearer, standing in the last print they
-- made, mends too. The passive self-heal is not a second effect bolted on: it falls out of the trail
-- itself, since the tile you stop on is a tile you blessed.
--
-- The `trail` passive (models/item.lua, fired at the Combat.enterTile chokepoint) rather than a trait:
-- there is no reaction here, only ground left behind. `side` is the wearer's, so hazard_heal's
-- ally-only onEnter means a foe chasing the priest down their own path gains nothing from it.
--
-- The trail is deliberately briefer than a cast Sanctuary (2 ticks against 4): a spell that spends a
-- turn to hallow one tile must outlast footprints that cost nothing at all.
return {
    name = "Pilgrim's Sandals",
    description = "Every tile you cross is left hallowed: you and your allies mend standing in your footsteps.",
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
    -- in it, which is the whole point of the boots.
    trail = { hazard = "hazard_heal", duration = 10 },
}
