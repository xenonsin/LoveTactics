-- RIDING: the Mare's end of Hag-Ridden (data/status/status_hag_ridden.lua). It sits on the sleeper and does not
-- get off of its own accord: it cannot walk while it rides. Strike it, or shove it off, and the ride is over
-- (trait_hag_ridden).
return {
    name = "Riding",
    abbr = "Ride",
    description = "Sitting on a sleeper: cannot move. Strike it to throw it off.",
    color = { 0.330, 0.260, 0.420 }, -- badge tint (nightmare violet, Hag-Ridden's)
    duration = 999,
    hideDuration = true,
    blocksMove = true,
}
