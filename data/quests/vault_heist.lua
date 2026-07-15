-- The Undercroft. Heavy on locked doors (keyCount) -- the map itself is the puzzle, and the
-- guards are only what happens when you take too long about it.
return {
    name = "The Vault Beneath",
    description = "A merchant prince keeps his vault behind three doors. The Undercroft has two keys.",
    difficulty = "Normal",
    sponsor = "undercroft",
    rewardGold = 150,
    rewardRep = 30,
    rewardPrestige = 1,
    requiredPrestige = 1,
    map = {
        biome = "castle",
        encounters = { min = 4, max = 7 },
        objective = {
            name = "The Vault Door",
            composition = function(ctx)
                local list = { "bandit_chief" }
                for i = 1, 1 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "champion" end
                return list
            end,
            win = { type = "assassinate", target = "bandit_chief" },
        },
        keyCount = 3,
    },
}
