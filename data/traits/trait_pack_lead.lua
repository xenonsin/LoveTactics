-- PACK LEAD: a marker, and nothing else executes here.
--
-- A body carrying this is a thing other wolves fight harder near. It has no `live`, no hook and no
-- effect of its own -- the reading is done from the OTHER side, by trait_runs_with_the_pack, which is
-- carried by every wolf and looks outward for a lead. That direction is forced rather than chosen:
-- Trait.liveBonus walks the traits of the unit whose stat is being read, so a passive can only ever
-- raise the stats of the body holding it. An aura in this engine is therefore always written as
-- "everyone looks for the leader", never as "the leader reaches out".
--
-- TWO FIGURES, BOTH TUNED BY THE ITEM THAT GRANTS IT (Trait.param, read off `traitParams`), which is
-- what lets one marker serve two very different animals:
--
--   packReach   how far the lead carries, in tiles. The Alpha Wolf's is 2 -- a ring you can stand
--               outside of, which is the counterplay its whole rung is built on. The White Wolf's is
--               the board: every wolf in the fight, wherever it is, because a god does not have a
--               radius. There is no escaping hers; you kill her or you kill the pack.
--   packDamage  what it is worth to a wolf inside that reach.
--
-- THE LARGEST APPLIES, NEVER THE SUM (see the reader). Her calls bring alphas onto a board she is
-- already standing on, so a wolf in both auras is the ordinary case rather than the corner one, and
-- summing would price the fight off a number nobody authored deliberately. One lead at a time -- the
-- best one -- keeps the tuning honest and keeps the readout legible: a wolf is buffed, or it is not.
return {
    name = "Pack Lead",
    description = "Increase damage for every wolf in reach of it.",
    packReach = 2,  -- default: an alpha's ring. Overridden per item (the White Wolf's covers the board)
    packDamage = 3, -- default: what standing with an alpha is worth
}
