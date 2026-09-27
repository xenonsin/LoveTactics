-- GATHERING: the Thousand-Winged's telegraph (models/swarm.lua). A swarm bat standing in a group of 3 or more wears
-- it, with the group's size as its count: at 4, at the end of the turn, the group fuses into the Thousand-Winged.
-- Redrawn at every turn's end, so the count is the board as the last turn left it. Kill one to break the group.
return {
    name = "Gathering",
    abbr = "Gath",
    description = "Stands with other bats. When 4 stand together at the end of a turn, they fuse into the Thousand-Winged.",
    color = { 0.560, 0.180, 0.220 }, -- badge tint (old blood)
    duration = math.huge,
    hideDuration = true, -- the count is the story
    hideLog = true,      -- redrawn every turn; the badge is the news, not the log
    magnitude = 1,
    stacks = 99,         -- a count, not a cap: Swarm.mark writes the group's size
}
