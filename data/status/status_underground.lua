-- UNDERGROUND: Delve's wind-up (data/items/ability/ability_delve.lua). The delver has gone down into the
-- floor and is coming up again on the tile the channel shows -- the telegraph the review asked for is the
-- channel's own ghost, a turn early, so the counterplay is to stand clear of the exit or be waiting on it.
--
-- Aloft's flags, turned upside down (data/status/status_aloft.lua): out of reach, cannot be struck,
-- moved or answer, until it surfaces. The channel sets the real length; the Delve ends it.
return {
    name = "Underground",
    abbr = "Down",
    description = "Delving: under the floor until it surfaces. It cannot be targeted, harmed by a blow, moved or answer.",
    color = { 0.470, 0.390, 0.300 }, -- badge tint (turned earth)
    duration = 10, -- a fallback; the channel sets the real length and the Delve ends it
    untargetable = true,
    immune = { physical = true, magical = true },
    disablesReactions = true,
    blocksMove = true,
    blocksForcedMove = true,
}
