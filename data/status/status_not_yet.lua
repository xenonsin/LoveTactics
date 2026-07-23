-- Not Yet: the bearer cannot die while it holds. Combat.dealFlatDamage reads `preventsDeath` and
-- floors the survivor at 1 health rather than dropping them -- the same flag Fury's berserk window
-- uses, and deliberately the same, because "you do not fall" should mean one thing in this game.
--
-- What it does NOT do is heal, and that gap is the entire design. The bearer spends the window at
-- whatever a hit left them, which is almost always one point -- so this is not a rescue but a DELAY of
-- a death, and the party has to spend the delay on something. A priest who casts it and then does
-- nothing has bought two turns of the same problem.
--
-- Short on purpose. A long one is just a tax on the enemy's turns; at two turns it is a window
-- somebody has to actually use, and the enemy can see it on the badge row and decide to go and kill
-- something else instead -- which is itself the priest winning.
--
-- Not resistible, and that is worth stating rather than leaving to silence: it is a BUFF the priest
-- puts on their own side, and the resistance curve exists to keep hard control from being permanent
-- (see the contract in models/status.lua). There is nothing here for a target's magic defense to argue
-- with.
return {
    name = "Not Yet",
    abbr = "NotY",
    description = "Cannot be killed: any blow leaves it standing at a sliver instead.",
    color = { 0.98, 0.90, 0.62 }, -- badge tint (a held candle)
    duration = 10,                -- ~2 turns: a window, not a state
    preventsDeath = true,
}
