-- DRUMBEAT: the War-Drummer's telegraph (data/traits/trait_the_march.lua). While it shows, the drum sounds at
-- the end of the Drummer's next turn, and every orc on its side takes one free step toward its nearest foe.
return {
    name = "Drumbeat",
    abbr = "Drum",
    description = "The drum sounds at the end of its next turn: every orc steps toward its nearest foe.",
    color = { 0.600, 0.420, 0.220 }, -- badge tint (drumskin)
    duration = math.huge,
    hideDuration = true,
}
