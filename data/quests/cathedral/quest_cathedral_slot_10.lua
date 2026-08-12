-- The end of the Cathedral's line, and one of the seven generals (docs/story.md). Gated on Saint -- rank
-- 4, the Cathedral's highest standing. `rewardItems` grants Luxuria's reliquary, which carries her rule;
-- `gateHint` is this general's fragment of the Gate Below's location, shown at the finale
-- (data/quests/quest_the_gate_below.lua, which already lists "quest_cathedral_slot_10" among its required quests, so the
-- place names itself one sin at a time). The real key is the completed QUEST, never the item.
--
-- The objective is `assassinate` rather than `killAll`: her guard is a wall to get through, not a thing to
-- grind down. Every turn spent on them is a turn her Rapture spends drinking your reserves
-- (character_general_lust.lua). Bring Amana, who feeds it nothing, and spend freely.
return {
    name = "The Unbidden",
    description = "The Cathedral has a patron beneath its nave, and she has taken from every soul that " ..
        "ever knelt there. Go and give her nothing.",
    difficulty = "Hard",
    sponsor = "cathedral",
    rewardGold = 500,
    rewardItems = { "utility_reliquary_unbidden" },
    -- The line's last quest: completing it settles what its ten offers came to, and decides whether
    -- Amana held, left, or caved (models/temptation.lua, docs/temptation.md). A data flag rather than
    -- a quest id the engine knows, exactly like `endsCampaign` on the finale.
    endsLine = true,
    requiredQuests = { "quest_cathedral_slot_09" }, -- slot 10: the line runs in order
    requiredPrestige = 1,
    gateHint = "under the nave, where the faithful were unmade",
    map = {
        biome = "castle",
        encounters = { min = 10, max = 14, always = { "encounter_elite", "encounter_elite" } },
        objective = {
            name = "Luxuria, the Unbidden",
            composition = function(ctx)
                local list = { "character_general_lust" }
                for i = 1, 2 + math.floor((ctx.day or 1) / 3) do list[#list + 1] = "character_champion" end
                return list
            end,
            opening = "conversation_cathedral_slot_10_confront",
            win = { type = "assassinate", target = "character_general_lust" },
        },
        keyCount = 2,
    },
}
