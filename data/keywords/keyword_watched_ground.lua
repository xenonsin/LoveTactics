-- Glossary entry for the `zone` field on a `waitBehavior` of kind "overwatch" -- this game's zone of
-- control. N is added to the cost of every tile orthogonally beside the watcher, for its enemies only
-- (Combat.watchTax). The mechanic lives in models/combat.lua; this owns only the word.
--
-- Said as a COST rather than as a stop on purpose, because that is what it is: the player who reads
-- this should understand they may still walk through, and that doing so will take the rest of the move
-- and put them further down the timeline for it.
return {
    name = "Watched Ground",
    description = "While the watch holds, tiles beside it cost N more for enemies to enter. Passable, but slow, and slow means further down the order.",
}
