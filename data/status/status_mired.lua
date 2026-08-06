-- Mired: bogged down in quicksand -- the exact opposite of Hasted. Every ability the unit uses and
-- every step it takes costs DOUBLE the timeline (`costMultiplier = 2`, the same knob Haste sets to
-- 0.5, folded into Combat.abilityCost and Combat.moveInitiative). Like Hasted it does not change how
-- FAR the unit can walk, only how much time the walk and its casts burn.
--
-- And it STOPS the walk that earned it (`stopsMovement`, Combat.stepMove): the tile that mires a unit
-- is the tile it finishes its move on. Only GAINING it halts -- a unit that was already mired when it
-- set off walks its whole route -- so the sand is a wall you walk into once, never a cage that refuses
-- to let you wade back out. The remaining route is cancelled, not banked: the move is spent, though it
-- is re-priced down to the ground actually crossed rather than the ground intended.
--
-- One exception, and it is the older rule winning: a body may cross a friendly's tile but never come to
-- rest on one. Sand with an ally already bogged down in it would make it do exactly that, so the walk
-- stops SHORT of that tile instead -- unmired, on the last clear ground behind it (Combat.stepMove,
-- and Combat.walkStop draws the route preview to the same place).
--
-- Delivered by the Quicksand hazard (data/hazards/hazard_quicksand.lua). It declares no `lingers`, so
-- it is ZONE-BOUND: the grant is stamped with that hazard as its `source`, it never ages, and it lasts
-- exactly as long as the unit stands on live quicksand -- lifting the instant it steps clear, or the
-- sand settles under it (Hazard.reap). Mirrors Sanctuary's Regeneration. A debuff, so Cure strips it --
-- though stepping onto the sand again re-applies it.
return {
    name = "Mired",
    abbr = "Mir",
    description = "Sinking: ability and movement costs are doubled, and gaining it ends the move.",
    color = { 0.670, 0.572, 0.375 }, -- badge tint (muddy tan)
    -- ~3 turns at Status.TICKS_PER_TURN, though it is only ever a backstop: Quicksand is the only
    -- thing that grants Mired, and a zone-bound status never ages -- the sand's own life is the timer.
    duration = 15,
    debuff = true,
    costMultiplier = 2,
    stopsMovement = true, -- landing this mid-walk ends the walk on that tile (see the header)
}
