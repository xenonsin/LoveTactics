-- TREMORS: each turn a slab of rubble falls onto an empty tile (data/walls/rubble.lua) -- it blocks the
-- way and a line until somebody breaks it. Capped, and never on ground an objective is decided on.
return {
    name = "Tremors",
    description = "Each turn, rubble falls on an empty tile and blocks it until broken.",
    color = { 0.66, 0.58, 0.46 },
    rubble = { wall = "rubble", count = 1, max = 6 },
}
