-- Tidewalker Boots: the wearer leaves the ground drenched, dropping a Rain tile (data/hazards/
-- hazard_rain.lua) on every tile it steps off. Reuses the mage's own cast rather than inventing a lesser
-- puddle, because everything that makes Rain worth casting is exactly what makes this worth walking:
-- it leaves crossers Wet, and its "conductable" tag lends the drenched TILE a charge, so a bolt landing
-- beside the trail arcs down it (Combat.tileHasTag). Walk the line, then Jolt it -- the boots are a
-- delivery system for a lightning caster standing behind them.
--
-- The trail is deliberately shorter-lived than a cast Rain (8 ticks against 15), on the Pilgrim's
-- Sandals' rule: a spell that spends a turn to soak one patch must outlast prints that cost nothing.
--
-- UNSIDED, and left that way deliberately: Rain wets whoever crosses it, the wearer's own line
-- included. Since a trail is laid behind (Combat.layTrail) the wearer normally escapes its own puddles,
-- but anyone following gets soaked, and so does the wearer the moment it doubles back. Wet is not damage
-- -- it is a lightning vulnerability -- so the cost is real but conditional, and a party with no
-- lightning to fear pays nothing at all. Gating the puddles to foes would soften a drawback that is
-- already the price of the synergy.
--
-- Note the trail does NOT put out fires it is laid over, though it is water-tagged: dousing runs off
-- the CAST path (Combat's cast footprint -> Hazard.douse), and laying a hazard directly never calls it.
-- Water terrain and a Rain cloud coexist with fire the same way. If these boots should steam out a
-- blaze they walk through, that is a change to Hazard.place, not something this blueprint already buys.
return {
    name = "Tidewalker Boots",
    description = "Leaves every tile you step off drenched: crossers are left Wet, and the wet ground conducts lightning.",
    flavor = "The first mage to wear them drowned no one. The second brought a friend who knew Jolt.",
    sprite = "assets/items/tidewalker_boots.png",
    type = "utility",
    tags = { "boots", "water" },
    class = "mage",
    price = 440,
    repRank = 2,
    trail = { hazard = "hazard_rain", duration = 8 },
}
