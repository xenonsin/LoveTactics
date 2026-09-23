-- UNHELD: there is nothing in it to take hold of, so nothing takes hold of it.
--
-- One flag and no other effect (`blocksForcedMove`), which is the whole of what a body made of moving
-- air is: a shove finds no shoulder, a hook finds no rib, a coil closes on a room's worth of draught
-- and shuts on itself. See models/status.lua -- the flag gates every shove, drag, throw and charge in
-- the game, in both directions.
--
-- AND IT CUTS BOTH WAYS, WHICH IS THE PRICE AND NOT A BUG. The same flag that refuses a mace refuses a
-- rescue, a Gaff Line, an ally's Pull, and several of the bearer's OWN leaps (Combat.charge reads it of
-- the user as well as of the target). Root's header already argues this at length and the argument is
-- the same one: a body that cannot be moved cannot be moved by its friends either, and pretending
-- otherwise would be saying two things about the same pair of feet.
--
-- NOT A DEBUFF, so a Cure does not lift it and the Cathedral's rite has nothing to lift. It is not
-- something that happened to the bearer -- it is what the bearer is made of, which is why the Wind Elemental
-- wears it from the opening bell (data/traits/trait_nothing_to_hold.lua) and why the piece that hands
-- it over hands over a permanent stance rather than a window.
--
-- 9999 ticks: the established "for the whole fight" duration (status_intercession, and the five
-- injuries). It answers to the battle, not to a clock.
return {
    name = "Unheld",
    abbr = "Uhl",
    description = "Cannot be moved: no shove, drag, throw or charge shifts it.",
    color = { 0.812, 0.890, 0.839 }, -- badge tint (the wind's own pale green, ELEMENT_TINT.wind)
    duration = 9999,
    blocksForcedMove = true,
}
