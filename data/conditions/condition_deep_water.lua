-- DEEP WATER: a band of water runs across the board between the two lines. It is the ford
-- (models/terrain.lua's `water`): two to enter, a swimmer crosses it at one, and it soaks whoever
-- stands in it (Arena.TERRAIN_ZONES stands the shallows on every tile) -- so the crossing is slow and
-- wet, and lightning finds it. Laid when the board is cut (models/condition.lua's Condition.layBand).
return {
    name = "Deep Water",
    description = "A band of water crosses the board: slow to wade, and it leaves you Wet.",
    color = { 0.30, 0.50, 0.62 },
    band = { terrain = "water", rows = 1 },
}
