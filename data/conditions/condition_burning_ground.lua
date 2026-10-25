-- BURNING GROUND: each turn, a few empty tiles catch fire. The ordinary Fire hazard
-- (data/hazards/hazard_fire.lua) -- Burn to whoever walks in, doused by water, and the AI already steps
-- around it -- set down on bare ground nobody stands on, so it closes the board rather than ambushing.
return {
    name = "Burning Ground",
    description = "Each turn, 2 empty tiles catch fire.",
    color = { 0.95, 0.55, 0.35 },
    ignite = { hazard = "hazard_fire", count = 2 },
}
