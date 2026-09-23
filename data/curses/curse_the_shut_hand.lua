-- THE SHUT HAND: nothing is given back to the bearer between fights.
--
-- THE FIRST HEX WHOSE SCOPE IS THE EXPEDITION rather than the fight, which is why it sits this deep.
-- `rules.noRecovery` is enforced at models/item_hook.lua's ctx.restore, and every between-fight restore
-- asks the RECEIVING body's rules -- so a larder carried by the company still feeds the other three and
-- says nothing at all to this one.
--
-- IT IS THE DESCENT'S OWN METER TURNED ON ONE BODY. What makes "push on or take the stair" a question is
-- that the company degrades as a dive runs long (models/injury.lua's opening). A body under this degrades
-- faster than the three beside it, and the player watches one bar fall out of step with the others for
-- the rest of the trip. That is a heavier thing than any number on this list, and it is priced as one.
--
-- THE FREE PATH STILL WORKS AND IS THE POINT. Two trips without the piece, or three hundred gold -- and
-- unlike every other hex here, the cost of NOT dealing with it is paid on the very next descent.
return {
    name = "The Shut Hand",
    description = "The bearer recovers nothing between fights, and cannot put the piece down.",
    binds = true,
    depth = 11,
    fee = 300,
    rules = { noRecovery = true },
}
