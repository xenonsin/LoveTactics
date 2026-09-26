-- SPECTATING: an orc watching the Blood Ring (data/traits/trait_the_blood_ring.lua). It stands at the ring's
-- edge and does nothing until a body falls and the crowd sends one of its own in (AI.preempt waits it). A
-- company body that ends its turn beside it is shoved back into the ring and struck.
return {
    name = "Spectating",
    abbr = "Crwd",
    description = "Watching the ring. Steps in when a body falls. Ending a turn beside it gets you shoved back in.",
    color = { 0.500, 0.450, 0.380 }, -- badge tint (dust)
    duration = math.huge,
    hideDuration = true,
}
