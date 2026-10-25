-- DARKNESS: nobody sees past two tiles. Every body on the board wears the Long Shadow's horizon
-- (`longShadow`, models/status.lua's Status.concealedAt): nothing aims at it from more than 2 tiles off,
-- and its own reach stops at 2 -- and every reach is a tile shorter on top (`abilityRange`, never under 1
-- or a bow's dead zone). One rule for both sides, so the planner is bound by it exactly as a driven body is.
return {
    name = "Darkness",
    description = "Nothing can be aimed at from more than 2 tiles. Every reach is 1 shorter.",
    color = { 0.45, 0.42, 0.62 },
    rules = { longShadow = 2, abilityRange = -1 },
}
