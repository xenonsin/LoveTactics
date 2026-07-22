-- The end of the Arcanum's line, and one of the seven generals (docs/story.md, "The Arcanum"). Gated on
-- Archmage -- rank 4, the Arcanum's highest standing. `rewardItems` grants Sublimitas's codex, which
-- carries her rule; `gateHint` is this general's fragment of the Gate Below's location, shown at the finale
-- (data/quests/the_gate_below.lua, which already lists "general_pride" among its required quests, so the
-- place names itself one sin at a time). The real key is the completed QUEST, never the item.
--
-- The objective is `assassinate` rather than `killAll`: her guard is a wall to get through, not a thing to
-- grind down. Bring what she cannot answer -- a party that stakes the fight on one big spell only hands it
-- to her (character_general_pride.lua). Gyeom, whom she cannot measure, is the party's own answer to her.
return {
    name = "The Unequalled",
    description = "The Arcanum's greatest mage has an answer for everything you can show her. Go and win " ..
        "with what you do not.",
    difficulty = "Hard",
    sponsor = "arcanum",
    rewardGold = 500,
    rewardRep = 80,
    rewardPrestige = 3,
    rewardItems = { "utility_codex_unanswered" },
    requiredPrestige = 5,
    requiredRep = { vendor = "arcanum", rank = 4 }, -- Archmage
    gateHint = "where the shelves answer only themselves",
    map = {
        biome = "castle",
        encounters = { min = 10, max = 14, always = { "encounter_elite", "encounter_elite" } },
        objective = {
            name = "Sublimitas, the Unequalled",
            composition = function(ctx)
                local list = { "character_general_pride" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_champion" end
                return list
            end,
            opening = "arcanum_general_pride_confront",
            win = { type = "assassinate", target = "character_general_pride" },
        },
        keyCount = 2,
    },
}
