-- Mired: bogged down in quicksand -- the exact opposite of Hasted. Every ability the unit uses and
-- every step it takes costs DOUBLE the timeline (`costMultiplier = 2`, the same knob Haste sets to
-- 0.5, folded into Combat.abilityCost and Combat.moveInitiative). Like Hasted it does not change how
-- FAR the unit can walk, only how much time the walk and its casts burn.
--
-- Delivered as an AURA by the Quicksand hazard (data/hazards/hazard_quicksand.lua): applied with
-- `source = "hazard_quicksand"`, it lasts only while the unit stands on live quicksand and lifts the
-- instant it steps clear (Combat.updateAuras), mirroring Sanctuary's Regeneration. A debuff, so Cure
-- strips it -- though it simply re-applies if the unit is still sinking.
return {
    name = "Mired",
    abbr = "Mir",
    description = "Sinking: ability and movement costs are doubled.",
    color = { 0.72, 0.60, 0.36 }, -- badge tint (muddy tan)
    duration = 6,
    debuff = true,
    costMultiplier = 2,
}
