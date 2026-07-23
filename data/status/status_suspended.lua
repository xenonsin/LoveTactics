-- Suspended: lifted off the board entirely. The bearer cannot act, cannot answer, cannot move, cannot
-- be aimed at, and comes back down a long way down the turn order.
--
-- Every flag here already existed; what is new is putting all of them on one status. That combination
-- is a genuinely different piece from any of its parts, and the difference is `untargetable`: this is
-- the only hard control in the game that PROTECTS what it lands on. A stun sets a target up to be
-- killed. A suspension takes it out of the fight in both directions at once.
--
-- Which makes it the rare control worth using on your OWN side. Suspending a dying ally is a real
-- rescue -- nothing can reach them while they hang -- paid for with the turn they lose on the way down.
-- Suspending an enemy is area denial that also, annoyingly, saves them from your own archers. There is
-- no configuration in which it is simply good, and that is the point of it.
--
-- The shove reads off `duration` rather than a separate magnitude, on Sleep's rule and for Sleep's
-- reason: resistance shortens the duration, and a shove that ignored that would be a resisted
-- suspension with a short badge and a full-length delay -- not a shorter effect, a bug wearing one.
return {
    name = "Suspended",
    abbr = "Susp",
    description = "Suspended: lifted off the field -- cannot act, be acted on, or answer.",
    color = { 0.74, 0.82, 0.94 }, -- badge tint (thin air)
    duration = 10,
    shovesInitiative = "duration",
    debuff = true,
    resistible = "magical",
    untargetable = true,
    disablesActions = true,
    disablesReactions = true,
    blocksMove = true,
    interruptsChannel = true, -- nobody finishes an incantation halfway up
}
