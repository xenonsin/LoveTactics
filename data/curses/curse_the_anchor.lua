-- THE ANCHOR: the bearer does not walk anywhere, ever.
--
-- THE DEEPEST AND THE BLUNTEST (`rules.noMove`). utility_rooted_oath sells this same immobility for
-- `abilityRange = 3, damageMultiplier = 1.5` -- stand still, reach further, hit harder -- and the trade
-- is a genuinely strong build. This is the stake with the payment removed, which is what a curse is on
-- this shelf: a rule of the game rewritten against the bearer rather than for them.
--
-- WHY A HEX THIS TOTAL IS ALLOWED TO EXIST. Because the room is free. A body that cannot move is
-- unplayable in a tactics game and would be an unfair thing to hand a player who had no answer -- but
-- the answer is two descents on the bench for one piece of gear, or four hundred gold, and the player
-- picks which. The severity is also what makes the rite mean anything by the eleventh floor: a rift
-- whose worst hex was -2 defense would have a Cathedral room nobody ever walked into.
--
-- AND IT IS STILL A POSITION RATHER THAN A DELETE, which is the argument Combat.applyUnitPassives makes
-- about the whole rule bag: a company that cannot move is a puzzle, and ONE knight who cannot move while
-- the other three can is a place to stand. A hexed body is a turret for a trip.
return {
    name = "The Anchor",
    description = "The bearer cannot move at all, and cannot put the piece down.",
    binds = true,
    depth = 13,
    fee = 400,
    rules = { noMove = true },
}
