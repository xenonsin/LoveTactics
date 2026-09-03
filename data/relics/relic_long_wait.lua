-- RARE. The company acts in BURSTS: several full actions when its turn comes up, and a turn that costs
-- far more of the timeline than anyone else's.
--
-- IT IS AUTHORED IN INITIATIVE, NOT IN ROUNDS, and that is the whole of how it works. This game has no
-- rounds -- combat is an initiative countdown (models/combat.lua's header): the lowest initiative acts
-- next, and ending a turn pays a price in it. "Every other round" is not a thing that can be expressed
-- here. "Your turn costs double" is, it is the same trade, and it is stated in the only currency the
-- timeline actually has.
--
-- WHY THE TWO NUMBERS ARE AUTHORED SEPARATELY. Combat.grantExtraAction already banks each surged
-- action's full price as tempo debt, so leaving it alone gives two actions for exactly two turns' worth
-- of initiative -- a perfect WASH. That is a real effect (two actions with no enemy beat between them is
-- how a burst finishes something before it can answer) but it is only worth an uncommon, and it makes a
-- second copy pay for itself exactly, which is not what a rare's ladder should do.
--
-- So the price is stated instead of emerging:
--
--   burstActions   2 -> 3 -> 4   how many actions the turn holds
--   initiativeCost 2, FLAT       what the turn costs, as a multiple
--
-- One copy is two actions for two turns of tempo: a wash on economy, bought for the ordering. TWO copies
-- is three actions for the same two turns -- the point where the relic stops being a trade and becomes
-- the reason the run is won. The multiplier deliberately does not ladder; if it did, every copy would
-- re-buy the same wash and the relic would never become anything.
return {
    name = "The Long Wait",
    blurb = "The company takes %d actions on its turn.",
    tier = "rare", mark = "Lw",
    cost = "Every turn costs 2x initiative, so the company acts half as often.",
    scale = { 2, 1 },
    rules = { burstActions = true, initiativeCost = true },
    ruleScale = {
        burstActions = { 2, 1 },   -- 2 actions, +1 per further copy
        initiativeCost = { 2, 0 }, -- always double; flat on purpose (see above)
    },
}
