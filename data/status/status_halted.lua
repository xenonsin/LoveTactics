-- Halted: ordered to stand down, and standing down. The unit may still WALK -- it simply may not act.
-- Every ability is refused while it lasts: a sword, a spell, a potion, the basic attack itself
-- (Combat.itemBlockReason reads Status.halted and greys every slot at once, exactly as Silence greys
-- the mana ones).
--
-- The line it draws is between doing and answering, and it deliberately does not cross it. A halted
-- knight still parries, still ripostes, still bites back through its thorns -- `disablesReactions` is
-- NOT set, which is what keeps this from being a second Stun wearing different words. Stun rattles you
-- out of the exchange entirely; this takes the initiative to start one and leaves the reflex to finish
-- it. Walk away, or stand there and be answered at.
--
-- That is Sloth said from the outside: the Bastion's answer to a sin of inaction is to inflict it. The
-- knight does not kill you, it decides what you are allowed to do -- and the sharpest version of that
-- is nothing at all (docs/classes.md: "It does not kill you, it decides where you stand").
--
-- Short on purpose. It costs its victim one action and not a battle, and a duration that outran a
-- single turn would be a Sleep that nothing wakes.
return {
    name = "Halted",
    abbr = "Hlt",
    description = "Halted: cannot use any ability. Movement and reflexes are untouched.",
    color = { 0.62, 0.58, 0.44 }, -- badge tint (dust and old brass -- an order, not a wound)
    duration = 5,  -- ~1 turn at Status.TICKS_PER_TURN: the one action it takes away
    debuff = true, -- removable by Cure
    disablesActions = true,
    resistible = "magical", -- a command is a working; a strong will buys back some of the silence
}
