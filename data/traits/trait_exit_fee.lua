-- EXIT FEE: the line rule of the Tollkeepers (models/toll.lua; "Sloth's Bestiary", 2026-10-04, slice F), carried by
-- every one of them on its organ, Mora included. A body of yours that steps out of a Tollkeeper's reach is struck on
-- the way out. Coming in is free.
--
-- A FLAG, NOT A HOOK. The step is the mover's, so the bearer cannot hear it: Combat.stepMove asks Toll.exitFee after
-- every walked tile, and that asks this flag of every keeper on the board -- the overwatch shot's seam, priced on
-- leaving instead of on arriving. Only a WALK pays; a shove, a pull or a blink carries a body out for nothing, which
-- is the counter the review wrote: commit where you engage, and use shoves to leave.
--
-- Mora carries it and never collects: the fee is a weapon's blow, and she has none.
return {
    name = "Exit Fee",
    description = "A foe that walks out of its reach is struck on the way out.",
    exitFee = true,
    notAReaction = true,
}
