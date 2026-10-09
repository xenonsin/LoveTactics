-- THE LAST HOUR: the Hollow Crown's count, phase 4 (models/hollow_crown.lua; slice D). At a quarter health a count of
-- 6 appears over the board, on the Crown's own badge (`badgeCount`, so the badge IS the number). Each of its turns
-- the count drops and it raises one Seal; a turn that opens on 0 swallows the board, and every body still standing
-- takes damage equal to its max health. Kill it before the count ends.
--
-- What the Crown is counting rather than a blessing: `undispellable`, so no strip and no grey water resets the clock.
return {
    name = "The Last Hour",
    abbr = "Hour",
    description = "Drops by 1 each of its turns. On the turn it opens at 0, every body still standing takes damage equal to its max health.",
    color = { 0.780, 0.250, 0.300 }, -- badge tint (the last red)
    duration = 9999,
    hideDuration = true,
    hideLog = true,
    undispellable = true,
    badgeCount = true,
    magnitude = 6,
}
