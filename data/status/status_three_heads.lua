-- THREE HEADS: the Vanguard's drop off Cerberus, worn for the turn it was called ("The Crown's Bestiary", slice C).
-- The bearer's next melee blow this turn also strikes up to two more foes beside it (trait_three_heads, read on the
-- swing's onCast), and the badge is spent by that blow. Unspent, it goes at the end of the turn: a breath taken for
-- one attack is not banked for the next.
return {
    name = "Three Heads",
    abbr = "3Hd",
    description = "Three Heads: your next melee blow this turn strikes up to three different adjacent foes.",
    color = { 0.690, 0.302, 0.192 }, -- badge tint (kennel red)
    duration = 5, -- one turn's worth at Status.TICKS_PER_TURN, ended with the turn below
    onTurnEnd = function(ctx) ctx.expire() end,
}
