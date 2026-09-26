-- HOARD: the gold the Brood Queen's scarabs have rolled into her nest (models/scarab.lua, Scarab.roll).
-- Counted in coin, one stack per gold piece, so the badge reads the hoard as it is. At
-- ability_roll_the_hoard's threshold she rolls the whole of it down a lane, and the count empties.
-- Reviewed 2026-09-25 ("The Coin-Eaters"): the hoard is the puzzle's clock, and the player reads it here.
return {
    name = "Hoard",
    abbr = "Hrd",
    description = "Gold rolled into the nest. At 20, the Queen rolls the whole hoard down a lane.",
    color = { 0.86, 0.70, 0.30 }, -- badge tint (coin)
    duration = 999,
    hideDuration = true, -- the count is the story
    magnitude = 1,
    stacks = 999,
}
