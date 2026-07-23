-- The Undercroft. Heavy on locked doors (keyCount) -- the map itself is the puzzle, and the
-- guards are only what happens when you take too long about it.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The Vault Beneath",
    description = "A merchant prince keeps his vault behind three doors. The Undercroft has two keys.",
    difficulty = "Normal",
    sponsor = "undercroft",
    rewardItems = { "armor_cutpurse_coat" },
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
                local list = { "character_bandit_chief" }
                for i = 1, 1 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_champion" end
                return list
            end,
            win = { type = "assassinate", target = "character_bandit_chief" },
        },
        keyCount = 3,
    },
}
