return {
    name = "The Haunted Mill",
    description = "Something stalks the old mill after dark. Investigate.",
    difficulty = "Normal",
    rewardGold = 120,
    requiredPrestige = 1,
    -- Overworld map generated when the quest starts (see models/overworld.lua).
    map = {
        biome = "forest",
        cols = 41, rows = 29,
        encounters = { min = 6, max = 9, always = { "elite" } },
        objective = { name = "The Miller's Ghost" },
        keyCount = 2,
    },
}
