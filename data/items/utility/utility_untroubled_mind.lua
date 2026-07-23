-- The Untroubled Mind: a Cathedral discipline rather than an object -- a litany drilled until the
-- reciting of it needs no attention, so there is nothing unattended for anything else to sit down in.
-- One of the four named immunities (see data/items/utility/utility_deadhand_grip.lua for the family).
--
-- It refuses Charm and Sleep: the two statuses that take a unit away from its owner rather than merely
-- hurting it. That pairing is the item, and it is why this is the Cathedral's and not the Arcanum's --
-- lust is the sin of being taken, and the priest's shelf is wards and holding ground against exactly
-- that (docs/classes.md: `negates`/`reflects`, `cleanse`/`dispel`). A ward against being turned is a
-- lust answer in a way that a ward against fire would not be.
--
-- These two are worth more than their tick counts suggest, which is the case for pricing it at rank 3
-- despite covering only a pair. Every other debuff in the game makes a unit worse; Charm makes it the
-- enemy's, and Sleep removes it from the fight entirely. Both are swings of two units rather than one,
-- and a party built around one irreplaceable caster is a party that loses to a single Charm.
--
-- Note the sharp edge: it does NOT cover Polymorph, Silence, or Stun. A mind that cannot be seduced can
-- still be gagged, rattled, or turned into a pig -- being proof against persuasion has never been the
-- same thing as being proof against force, and this item is very specifically about the former.
return {
    name = "Untroubled Mind",
    description = "The self stays its own: immune to Charm and Sleep.",
    flavor = "Recited until the reciting needs no attention. There is then nothing unattended to sit down in.",
    sprite = "assets/items/untroubled_mind.png",
    type = "utility",
    tags = { "charm", "holy" },
    class = "priest",
    price = 440,
    repRank = 3,
    statusImmunity = { "status_charm", "status_sleep" },
}
