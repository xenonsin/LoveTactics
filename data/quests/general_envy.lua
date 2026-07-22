-- The end of the Crucible's line, and one of the seven generals (docs/story.md, "The Crucible"). Gated on
-- Philosopher -- rank 4, the Crucible's highest standing. `rewardItems` grants Livia's Glass, which
-- carries her rule; `gateHint` is this general's fragment of the Gate Below's location, shown at the
-- finale (data/quests/the_gate_below.lua, which already lists "general_envy" among its required quests).
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
    rewardRep = 80,
    rewardPrestige = 3,
    rewardItems = { "utility_envious_glass" },
    requiredPrestige = 5,
    requiredRep = { vendor = "alchemist", rank = 4 }, -- Philosopher
    gateHint = "below the vats, where the shapeless envy the shaped",
    map = {
        biome = "castle",
        encounters = { min = 10, max = 14, always = { "encounter_elite", "encounter_elite" } },
        objective = {
            name = "Livia, the Unborn",
            composition = function(ctx)
                local list = { "character_general_envy" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_homunculus" end
                return list
            end,
            opening = "crucible_general_envy_confront",
            win = { type = "assassinate", target = "character_general_envy" },
        },
        keyCount = 2,
    },
}
