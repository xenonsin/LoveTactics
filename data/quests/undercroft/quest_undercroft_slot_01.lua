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
    -- The thanks for the job that OPENS this house. Its opener is seated on a descent floor unasked
    -- (models/errand.lua), so this scene is where the house first learns who ran it -- and the greeting
    -- waiting at its counter picks up from these lines.
    outro = "conversation_undercroft_slot_01_outro",
    rewardItems = { "armor_cutpurse_coat" },
    rewardGold = 150,
    -- THE COMPANION JOINS HERE. This is the ask they make when you meet them on a floor
    -- (models/errand.lua), and clearing it is what brings them into the company -- the same
    -- route Saber has always arrived by. Quest.complete calls Player.recruit before the outro
    -- fires, so the "[X has joined your Party]" banner and their first words land in one beat.
    rewardCharacter = "character_clem",
    requiredPrestige = 3,
    map = {
        biome = "castle",
        encounters = { min = 4, max = 7 },
        objective = {
            name = "The Vault Door",
            composition = function(ctx)
                local list = { "character_bandit_chief" }
                for i = 1, 1 + math.floor((ctx.day or 1) / 2) do list[#list + 1] = "character_champion" end
                return list
            end,
            win = { type = "assassinate", target = "character_bandit_chief",
                enemy = "the vault's keeper" },
        },
        keyCount = 3,
    },
}
