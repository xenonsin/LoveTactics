-- SINGLE COMBAT: the Peerless is enormous against one body and ordinary against four.
--
-- Every other apex in this pass occupies ground -- a four-tile body closing a door, a road, a dry line
-- through a mire. The Peerless refuses to be surrounded instead, and this is the rule that makes that a
-- mechanic rather than a line of flavour.
--
-- WHICH INVERTS ITS OWN CIRCLE. On every other floor of the castle a warren is where you BREAK a rank
-- (data/traits/trait_close_ranks.lua): pull them through a doorway and the formation stops paying. Here
-- the doorway is the Peerless's advantage, because a corridor is a place where only one of you can reach
-- it at a time. The player's habit from the whole rest of the stratum is exactly the wrong instinct.
--
-- So the counterplay is the thing the circle has spent four fights teaching you not to do: take it into
-- the open and swarm it.
--
-- `live` rather than a hook, for Formation Fighter's reason: this is a claim about the field as it
-- currently stands, so nothing is banked and stepping a second body in removes it in the same instant.
return {
    name = "Single Combat",
    description = "Gains damage and defense while exactly one foe stands beside it.",
    live = function(ctx)
        if ctx.count(1, "foe") ~= 1 then return nil end
        return { damage = 8, defense = 6 }
    end,
}
