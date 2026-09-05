-- Contagion: the alchemist half of the Plague Knight (knight x alchemist), and the discipline's
-- signature. Every poisoned body on the field passes the sickness to your foes standing beside it, at
-- the top of your turn.
--
-- A PASSIVE, which was the author's correction and rule R4: standing beside you sickens, and pressing a
-- button for it made the plague a performance rather than a condition. It is also why this sits on the
-- Crucible's shelf as a charm rather than as the ability it was drafted as -- the Plague Knight had both
-- its items on the knight shelf, so its alchemist parent unlocked a discipline and then sold nothing
-- for it.
--
-- It reads poisoned BODIES rather than poisoned enemies, which is the clause that makes the
-- Plaguebearer's Draught a plan instead of a wound: poison yourself and you become the source, standing
-- in the middle of their line. Only your own foes ever catch it.
--
-- One turn, one step. The spread is gathered before any of it lands, so a body infected this turn does
-- not itself infect on the same turn -- otherwise one sick body in a packed rank would take the whole
-- rank at once and this would read as a free area spell.
return {
    name = "Contagion",
    description = "At the start of your turn, every poisoned body infects your foes standing beside it.",
    flavor = "It does not belong to him. He simply stopped being the thing that contained it.",
    sprite = "assets/items/utility_contagion.png",
    type = "utility",
    tags = { "charm", "poison" },
    class = "plague_knight",
    unlockQuests = 2,
    dropTier = 2,
    traits = { "trait_contagion" },
    -- the spread is the weapon
    bonus = { magicDamage = 2 },
}
