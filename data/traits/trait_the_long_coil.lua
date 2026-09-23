-- THE LONG COIL: an Elder's tether grows teeth with distance. Every tile past the circle is worth
-- another bite.
--
-- THE ALPHA'S ESCALATION, AND IT IS THE SAME SENTENCE RATHER THAN A SECOND ONE. A plain lamia's coil
-- is flat: leave the circle, take a fixed bite, and a company that decides the ground is worth it pays
-- a known price once per turn (data/status/status_coiled.lua). Hers is a slope -- so the question
-- stops being WHETHER to leave and becomes HOW FAR, which is a decision with a dial on it rather than
-- a toll with a number on it.
--
-- AND IT TURNS THE FLOCK INTO HER ARTILLERY. A harpy's gust moves a body one tile; against her tether
-- that tile is a rung on her damage curve, delivered by somebody else's wings and costing her nothing.
-- The deeper the stratum stacks its own bodies, the more this reads -- which is exactly what an elite
-- rung is for, and why the Eyrie and the Drowned Stair belong on the same ladder.
--
-- IT IS STAMPED, NOT COMPUTED HERE. The bite lives in the status, because "where is this body right
-- now, relative to that one" is a recurring check against the board and onTurnEnd is the hook for it;
-- all this does is mark her applications as the steep kind. That split is status_sworn's own argument
-- and it is followed deliberately -- a second copy of the distance check on this side would be two
-- rulers for one measurement.
--
-- WHICH MAKES IT WORK THROUGH ANY DELIVERER. She could be handed a second coiling weapon tomorrow and
-- the slope would ride it, because what this reads is the STATUS landing and not the fang that landed
-- it (Trait.onStatusApplied's applier side -- the same door trait_executioners_eye comes through).
return {
    name = "The Long Coil",
    description = "Increase the tether's bite for every tile past its circle.",
    -- Extra damage per tile beyond status_coiled's radius. Two rather than four: the status caps the
    -- whole bite at twice its flat toll, so a steeper slope only reaches that ceiling sooner and
    -- flattens the difference between running three tiles and running six -- which is the decision
    -- the curve exists to create. At two, the dial is live across the tiles a company actually uses.
    perTile = 2,
    onStatusApplied = function(ctx)
        if ctx.role ~= "applier" then return end
        if (ctx.status and ctx.status.id) ~= "status_coiled" then return end
        ctx.status.perTile = ctx.def.perTile or 4
    end,
}
