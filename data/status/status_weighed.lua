-- WEIGHED: the heavier heart on a Jackal Weigher's scale (models/envy_oneoffs.lua; "Envy's Bestiary", round 2).
-- Every Weigher on the field goes for this body (AI.preempt) until the next weighing sets another pair down.
--
-- A reading rather than a curse, so it is not a debuff and no Cure lifts it -- what moves it is the next
-- weighing, and what decides that is current health. Never stripped as a blessing either.
return {
    name = "Weighed",
    abbr = "Hvy",
    description = "Weighed: the heart that sank on the scale. Every Weigher strikes it.",
    color = { 0.700, 0.320, 0.260 }, -- badge tint (the pan that sinks)
    duration = 99, -- a backstop; the next weighing takes it off
    hideDuration = true,
    undispellable = true,
}
