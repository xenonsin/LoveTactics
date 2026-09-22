-- The Undercroft. Heavy on locked doors (keyCount) -- the map itself is the puzzle, and the
-- guards are only what happens when you take too long about it.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The Vault Beneath",
    -- The work in one line, read as a spoken line rather than as a notice on a board: the city has no
    -- Quest Board any more, and the only code that reads this field is the companion posting scenes
    -- through `{posting}` (states/game.lua sets player.postingWork off it). Written to the premise the
    -- meeting scenes stand on: the rift copies places, and hers is standing on a floor of it.
    description = "A vault door in the rift carries the Bank's own mark. Three doors, two keys, and " ..
        "a keeper behind the last one who is still counting.",
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
                for i = 1, 1 + math.floor((ctx.depth or 1) / 1) do list[#list + 1] = "character_champion" end
                return list
            end,
            win = { type = "assassinate", target = "character_bandit_chief",
                enemy = "the vault's keeper" },
        },
        keyCount = 3,
    },
}
