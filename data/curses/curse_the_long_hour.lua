-- THE LONG HOUR: every turn the bearer takes costs more of the clock than it should.
--
-- THE LONG WAIT'S MULTIPLIER WITHOUT THE LONG WAIT'S BURST (`rules.initiativeCost`, applied at Combat's
-- turn settle). utility_long_wait sells `burstActions = 2, initiativeCost = 2` -- two actions for a
-- doubled wait -- and the trade is what makes it an item. This is the price half on its own, which is
-- what a curse IS on this shelf: a cost the game already knows how to charge, with the thing it was
-- buying taken away.
--
-- 1.35 RATHER THAN THE ITEM'S 2. A doubled turn is a body that acts roughly half as often, which on a
-- four-body company is closer to removing a member than to hexing a sword. A third again is felt on the
-- timeline -- the bearer slips a place or two in the order every round -- without the fight quietly
-- becoming three against four.
--
-- A WAIT IS STILL CHEAP, which the settle handles and is worth knowing here: Combat.wait lands one tick
-- after the next unit by definition and is not multiplied. A hexed body can still pass the turn
-- normally; ACTING is what costs, which is the right shape for this.
return {
    name = "The Long Hour",
    description = "Every turn the bearer acts on costs 35% more of the clock.",
    binds = true,
    depth = 7,
    fee = 220,
    rules = { initiativeCost = 1.35 },
}
