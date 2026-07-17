-- Mired: bogged down in quicksand -- the exact opposite of Hasted. Every ability the unit uses and
-- every step it takes costs DOUBLE the timeline (`costMultiplier = 2`, the same knob Haste sets to
-- 0.5, folded into Combat.abilityCost and Combat.moveInitiative). Like Hasted it does not change how
-- FAR the unit can walk, only how much time the walk and its casts burn.
--
-- Delivered by the Quicksand hazard (data/hazards/hazard_quicksand.lua). It declares no `lingers`, so
-- it is ZONE-BOUND: the grant is stamped with that hazard as its `source`, it never ages, and it lasts
-- exactly as long as the unit stands on live quicksand -- lifting the instant it steps clear, or the
-- sand settles under it (Hazard.reap). Mirrors Sanctuary's Regeneration. A debuff, so Cure strips it --
-- though stepping onto the sand again re-applies it.
return {
    name = "Mired",
    abbr = "Mir",
    description = "Sinking: ability and movement costs are doubled.",
    color = { 0.72, 0.60, 0.36 }, -- badge tint (muddy tan)
    -- ~3 turns at Status.TICKS_PER_TURN, though it is only ever a backstop: Quicksand is the only
    -- thing that grants Mired, and a zone-bound status never ages -- the sand's own life is the timer.
    duration = 15,
    debuff = true,
    costMultiplier = 2,
}
