-- The end of the Cathedral's line, and one of the seven generals (docs/story.md). Gated on Saint -- rank
-- 4, the Cathedral's highest standing. `rewardItems` grants Luxuria's reliquary, which carries her rule;
-- `gateHint` is this general's fragment of the Gate Below's location, shown at the finale
-- (data/quests/the_gate_below.lua, which already lists "general_lust" among its required quests, so the
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
    rewardRep = 80,
    rewardPrestige = 3,
    rewardItems = { "utility_reliquary_unbidden" },
    requiredPrestige = 5,
    requiredRep = { vendor = "cathedral", rank = 4 }, -- Saint
    gateHint = "under the nave, where the faithful were unmade",
    map = {
        biome = "castle",
        encounters = { min = 10, max = 14, always = { "encounter_elite", "encounter_elite" } },
        objective = {
            name = "Luxuria, the Unbidden",
            composition = function(ctx)
                local list = { "character_general_lust" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_champion" end
                return list
            end,
            opening = "cathedral_general_lust_confront",
            win = { type = "assassinate", target = "character_general_lust" },
        },
        keyCount = 2,
    },
}
