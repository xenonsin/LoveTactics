-- The end of the Undercroft's line, and one of the seven generals (docs/story.md, "The Undercroft").
-- Gated on Guildmaster -- rank 4, the Undercroft's highest standing. `rewardItems` grants Aurea's Purse,
-- which carries her rule; `gateHint` is this general's fragment of the Gate Below's location, shown at the
-- finale (data/quests/the_gate_below.lua, which already lists "general_greed" among its required quests).
-- The real key is the completed QUEST, never the item.
--
-- The objective is `assassinate` rather than `killAll`: her retinue is a wall to get through, not a thing
-- to grind down. Killing her cancels no notes and frees no one -- the debt was the pact, not the gold --
-- but the quest is the key all the same (character_general_greed.lua).
return {
    name = "The Ever-Owed",
    description = "The whole city owes her, and she can spend none of it. End the creditor who starves " ..
        "at her own table.",
    difficulty = "Hard",
    sponsor = "undercroft",
    rewardGold = 500,
    rewardRep = 80,
    rewardPrestige = 3,
    rewardItems = { "utility_bottomless_purse" },
    requiredPrestige = 5,
    requiredRep = { vendor = "undercroft", rank = 4 }, -- Guildmaster
    gateHint = "beneath the vault that was never full",
    map = {
        biome = "castle",
        encounters = { min = 10, max = 14, always = { "encounter_elite", "encounter_elite" } },
        objective = {
            name = "Aurea, the Ever-Owed",
            composition = function(ctx)
                local list = { "character_general_greed" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_bandit_chief" end
                return list
            end,
            opening = "undercroft_general_greed_confront",
            win = { type = "assassinate", target = "character_general_greed" },
        },
        keyCount = 2,
    },
}
