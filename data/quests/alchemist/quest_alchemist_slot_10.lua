-- The end of the Crucible's line, and one of the seven generals (docs/story.md, "The Crucible"). Gated on
-- Philosopher -- rank 4, the Crucible's highest standing. `rewardItems` grants Livia's Glass, which
-- carries her rule; `gateHint` is this general's fragment of the Gate Below's location, shown at the
-- finale (data/quests/quest_the_gate_below.lua, which already lists "quest_alchemist_slot_10" among its required quests).
-- The real key is the completed QUEST, never the item.
--
-- The objective is `assassinate` rather than `killAll`: her counterfeits are a wall to get through, not a
-- thing to grind down. Bring a party that does not tower -- let one unit stand far above the rest and you
-- only hand her its shape (character_general_envy.lua). Ren, who compresses the party upward, is the
-- party's own answer.
return {
    name = "The Unborn",
    description = "The college's masterpiece has no shape of its own -- so it opens every fight wearing " ..
        "your best. Win with a party that has no single tower to covet.",
    difficulty = "Hard",
    sponsor = "alchemist",
    rewardGold = 500,
    rewardItems = { "utility_envious_glass" },
    requiredQuests = { "quest_alchemist_slot_09" }, -- slot 10: the line runs in order
    requiredPrestige = 4,
    gateHint = "below the vats, where the shapeless envy the shaped",
    map = {
        biome = "swamp",
        encounters = { min = 10, max = 14, always = { "encounter_elite", "encounter_elite" } },
        objective = {
            name = "Livia, the Unborn",
            composition = function(ctx)
                local list = { "character_general_envy" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_homunculus" end
                return list
            end,
            opening = "conversation_alchemist_slot_10_confront",
            win = { type = "assassinate", target = "character_general_envy" },
        },
        keyCount = 2,
    },
}
