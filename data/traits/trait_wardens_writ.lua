-- Warden's Writ: the standing rule of the Warden's charm of the same name. Every hazard its bearer
-- lays down also Halts the foes that walk into it.
--
-- A FLAG (Trait.flag), read by fx.placeHazard at the moment of placement, which stamps `halts` onto the
-- zone INSTANCE. Never onto the blueprint: the hazard defs are shared, and a warden who made the
-- world's fire Halting would be rewriting everyone else's spells.
--
-- The generality is the point, and it is what the word "zone" was hiding. There is no zone layer in this
-- engine -- there are hazards, 34 items place them, and 32 more carry incense. So the Warden does not
-- get a bespoke lockdown field; it gets a clause that attaches to every piece of ground anyone ever
-- authors. A warden's Fireball Halts. A warden's Rain Halts. Anything added next year Halts.
return {
    name = "Warden's Writ",
    haltsOwnHazards = true,
}
