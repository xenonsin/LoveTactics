-- HEAD DOWN: the Minotaur's last third (models/labyrinth.lua). Put on beside Fury the moment it falls below a
-- third of its health, and never taken off. +1 movement; it runs straight at the nearest body through every wall
-- (Labyrinth.plan), and its Run drives back one tile per tile (Labyrinth.runDistance).
return {
    name = "Head Down",
    abbr = "Hd",
    description = "Head Down: +1 movement. It runs straight at the nearest body, and its charge drives back a tile per tile run.",
    color = { 0.620, 0.180, 0.110 }, -- badge tint (bull red)
    duration = math.huge,
    hideDuration = true,
    statBonus = { movement = 1 },
}
