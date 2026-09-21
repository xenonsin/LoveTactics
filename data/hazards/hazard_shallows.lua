-- The shallows: standing water, and it soaks whoever wades it.
--
-- Stood on every `water` tile a board lays (Arena.TERRAIN_ZONES), so this is the ford admitting what
-- it always was. The tile has carried `conductable` since the beginning -- a bolt has always arced
-- through a river -- and everybody read that as a fact about the GROUND. It is now also a fact about
-- the BODY: wade the ford and you come out wet, and Wet carries its own conduction with it
-- (status_wet's `tileTags`), so the charge follows you onto dry land for three turns.
--
-- WET LINGERS, which is the one thing that makes this different in kind from the mire's Mired. A bog
-- has you while you are in it and lets go the moment you climb out; water does not dry that fast. So
-- this grants and the status keeps its own clock, rather than binding to the zone -- and standing in
-- the ford simply refreshes it. That is status_wet's own declaration, not a choice made here, which is
-- the arrangement docs/terrain.md argues for: the status decides whether it clings to its ground.
--
-- HOSTILE, and it is worth being honest about what that costs: every AI on every board with water on
-- it now prefers to path around the ford. That is the correct reading -- Wet is a debuff, and a
-- planner that walked its own line into a conductor because the tile was a short cut would be a
-- planner with a bug -- but it is a real change to boards that have existed for a long time.
--
-- The faction this was written beside is the reason it is worth the change. The Mere's whole kit is
-- one sentence -- the lancer soaks, the caller conducts, the undertow drags -- and before this the
-- ford was the one piece of that sentence the board could not say for itself.
return {
    name = "Shallows",
    description = "Soaks whoever stands in it.",
    tags = { "water" },
    duration = 9999,          -- the ground does not expire; the caller quotes this too
    disposition = "hostile",  -- a planner should not walk its own line into a conductor
    onEnter = function(ctx)
        -- Wet declares `lingers`, so this is NOT stamped with the zone as its source: it travels with
        -- the body and dries on its own fifteen ticks. Re-entering just refreshes it.
        ctx.applyStatus(ctx.unit, "status_wet")
    end,
}
