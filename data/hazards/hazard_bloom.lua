-- NEW GROWTH: what comes up behind a Meandering Stag, and the first heal in this game that is on
-- nobody's side.
--
-- IT MENDS WHATEVER STANDS ON IT. Every other friendly zone in the catalogue opens with the same
-- guard -- `if not ctx.isAlly(ctx.unit) then return end` -- so a Sanctuary blesses the priest's line
-- and the bandits standing in it get nothing (hazard_heal, hazard_renewal, hazard_wellspring, all
-- three). This one has no such line, and the absence IS the design: the stag is not helping you. It is
-- doing what it does, where it happens to be, and your knight and the wolf chasing your knight are
-- both standing there.
--
-- `disposition = "friendly"` is about PATHING and nothing else (Hazard.tileBias), which is why it does
-- not contradict the paragraph above. It draws the enemy AI onto ground the stag has made -- so the
-- wood it brought with it fights on the tiles the stag is mending, which is the shape of the first
-- half of the fight. The party needs no bias; the player moves them, and they can see it is green.
--
-- THE TRAIL IS THE MECHANIC, SO THE CLOCK IS LONG. Sixty ticks is roughly twelve turns -- far longer
-- than any other trail in the game (Cinderstride's fire runs 8, Wellspring's print 10) -- because
-- those are laid to be used now and this one is laid to be COUNTED later. Every tile still standing
-- when the stag turns becomes blight in the same instant (Hazard.convert), and a print that expired
-- quietly on turn four is a tile the party never has to answer for. What the company let it walk has
-- to still be on the floor when the bill arrives.
--
-- GRANTS REGENERATION rather than pouring health directly, on the Sanctuary's rule and for its reason:
-- a zone-bound status is refreshed every tick the body remains and lapses the moment it steps off, so
-- "mends whatever stands on it" needs no per-tick hook here and no way to farm it by pacing.
return {
    name = "New Growth",
    description = "Mends whatever stands on it, whoever it belongs to.",
    tags = { "nature" },
    duration = 60,           -- ~12 turns: this trail is counted at the threshold, not spent in the moment
    disposition = "friendly", -- pathing only (see above): the wood is drawn onto its own ground
    onEnter = function(ctx)
        -- No allegiance check. See the header -- this is the line every other friendly zone has and
        -- this one does not, and deleting it is the whole item.
        ctx.applyStatus(ctx.unit, "status_regen", { magnitude = ctx.amount })
    end,
}
