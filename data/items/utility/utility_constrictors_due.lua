-- CONSTRICTOR'S DUE: what a company carries out of the Drowned Stair, and it is the Elder's patience
-- rather than her string.
--
-- She does not hold you harder than her line does -- the knot and the fang are the same two weapons
-- the young ones swing. What she has is the SLOPE: everything already caught is worth more to her
-- (data/traits/trait_the_long_coil.lua). This is that, handed over as a flat due on anything that
-- cannot leave. See data/traits/trait_constrictors_due.lua for which three statuses count and why
-- Freeze and Stun deliberately do not.
--
-- ITS OTHER HALF FALLS OFF THE SAME CIRCLE. utility_the_slow_circle -- the Lamia's drop -- is how a
-- bearer with no hold in its kit gets one. A player who walks out of a Lust floor with both has been
-- taught a rule in two halves and sold both of them, which is the shape a stratum's drop table should
-- have; a player who walks out with one has a reason to go back down.
--
-- `class` IS THE VENDOR SHELF AND NEVER AN EQUIP GATE (docs/classes.md). The Warden is where holding
-- ground is written down -- Warding Line, the Grasping Hollow, Marchstone and the Writ all put bodies
-- in Root or Halt, and utility_bound_mile makes those holds permanent -- so a due on held things
-- belongs on that counter. Not who is allowed to collect it.
--
-- FOUND IN THE RIFT, NOT DEALT OVER A COUNTER (docs/shelf.md): no `price`, so a counter stocks it only
-- once the class has climbed to its rung.
return {
    name = "Constrictor's Due",
    description = "Increase damage against anything that cannot leave.",
    flavor = "The young ones bite and let go and bite again. She has only ever had to do the one thing.",
    sprite = "assets/items/constrictors_due.png",
    type = "utility",
    tags = { "charm", "dark" },
    class = "warden",
    unlockLevel = 5,
    traits = { "trait_constrictors_due" },
}
