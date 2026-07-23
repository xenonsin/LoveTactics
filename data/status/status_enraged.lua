-- Enraged: the visible face of the phase system's enrage curve (data/traits/trait_boss_phases.lua's
-- `enrage` response, first worn by the Demon Champion at 33% health). Like Wrath
-- (data/status/status_wrath.lua) it grants NOTHING on its own -- the trait already added the damage to
-- the unit's per-battle bonus; this badge only lets the player watch the number climb and understand,
-- before it is too late, that grinding it down is how it wakes up.
--
-- The number tracks MISSING HEALTH, not blows landed: it steps up as the bearer is emptied, so the
-- badge and its health bar tell the same story from opposite ends.
return {
    name = "Enraged",
    abbr = "Enr",
    description = "Worse the nearer it is to death: every wound sharpens its next blow.",
    color = { 0.85, 0.2, 0.15 }, -- badge tint (arterial red)
    duration = 999,       -- it does not cool; it lasts the battle
    hideDuration = true,  -- the countdown is meaningless -- the magnitude is the story
    magnitude = 0,        -- overwritten each hit with the total damage banked (display only)
}
