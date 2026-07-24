-- Contagion: the standing rule of the Plague Knight's charm of the same name. At the top of the
-- bearer's turn, every poisoned body on the field passes the sickness to the bearer's foes standing
-- beside it.
--
-- A PASSIVE, which is rule R4 and was the author's own correction: "standing beside you sickens" is a
-- condition, not a button, and an active version made the plague something the knight performed rather
-- than something it was. A flag (Trait.flag) read in Combat.startTurn, spreading through
-- Combat.spreadContagion.
--
-- It reads POISONED BODIES, not poisoned enemies -- which is what turns the Plaguebearer's Draught from
-- self-harm into a plan. A plague knight who has poisoned itself is a source, and the sickness spreads
-- out of its own tile into everyone it is standing among. Only ever the bearer's foes catch it.
--
-- The spread is gathered before any of it is applied, so a body infected this turn cannot itself spread
-- on the same turn. Without that, one poisoned unit in a packed line sickens the whole line at once and
-- the mechanic reads as a free area spell rather than as a plague.
return {
    name = "Contagion",
    spreadsPoison = true,
}
