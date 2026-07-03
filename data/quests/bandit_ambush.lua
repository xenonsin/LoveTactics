-- Quest blueprint. `requiredPrestige` gates when the quest appears on the
-- board; `Quest.available(prestige)` filters on it.
return {
    name = "Bandit Ambush",
    description = "Raiders have blocked the north road. Clear them out.",
    difficulty = "Easy",
    rewardGold = 50,
    requiredPrestige = 1,
    -- Overworld map generated when the quest starts (see models/overworld.lua).
    map = {
        biome = "forest",
        cols = 31, rows = 21,
        encounters = { min = 4, max = 6 }, -- rivers come from the biome
        objective = { name = "Bandit Chief" },
        keyCount = 0,
    },
}
