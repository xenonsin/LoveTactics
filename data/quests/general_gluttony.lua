-- The end of the Hunter's Lodge line, and one of the seven generals (docs/story.md, "The Hunter's
-- Lodge"). Gated on Grand Hunter -- rank 4, the Lodge's highest standing. `rewardItems` grants Gula's
-- Maw, which carries her rule; `gateHint` is this general's fragment of the Gate Below's location, shown
-- at the finale (data/quests/the_gate_below.lua, which already lists "general_gluttony" among its
-- required quests). The real key is the completed QUEST, never the item.
--
-- The objective is `assassinate` rather than `killAll`: her pack is a wall to get through, not a thing to
-- grind down -- and grinding is exactly what feeds a heal-on-hit foe (character_general_gluttony.lua).
-- Bring Kaya, whom she cannot feed on, and end it fast.
return {
    name = "The Unsated",
    description = "The beast at the heart of the deep wood was the Lodge's greatest hunter once. End " ..
        "her before the long trade makes her whole.",
    difficulty = "Hard",
    sponsor = "hunters_lodge",
    rewardGold = 500,
    rewardRep = 80,
    rewardPrestige = 3,
    rewardItems = { "utility_maw_of_the_unfed" },
    requiredPrestige = 5,
    requiredRep = { vendor = "hunters_lodge", rank = 4 }, -- Grand Hunter
    gateHint = "at the heart of the wood the hunt hollowed out",
    map = {
        biome = "forest",
        encounters = { min = 10, max = 14, always = { "encounter_elite", "encounter_elite" } },
        objective = {
            name = "Gula, the Unsated",
            composition = function(ctx)
                local list = { "character_general_gluttony" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_wolf_alpha" end
                return list
            end,
            opening = "hunters_lodge_general_gluttony_confront",
            win = { type = "assassinate", target = "character_general_gluttony" },
        },
        keyCount = 2,
    },
}
