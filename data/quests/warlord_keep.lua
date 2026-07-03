return {
    name = "Siege of Warlord's Keep",
    description = "Storm the warlord's stronghold. Only the renowned need apply.",
    difficulty = "Hard",
    rewardGold = 300,
    requiredPrestige = 3,
    -- Overworld map generated when the quest starts (see models/overworld.lua).
    map = {
        biome = "castle",
        cols = 51, rows = 35,
        encounters = { min = 10, max = 14, always = { "elite", "elite" } },
        objective = { name = "The Warlord" },
        keyCount = 2,
    },
}
