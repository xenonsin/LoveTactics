-- The Arcanum. Looters got to the sanctum first; the Arcanum would like its book back, and is
-- not especially concerned about the looters.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The Sunken Sanctum",
    description = "A grimoire lies in the flooded ruins. Others are already digging for it.",
    difficulty = "Normal",
    sponsor = "arcanum",
    rewardItems = { "weapon_iron_crook", "armor_gleaners_mantle" },
    rewardGold = 140,
    rewardRep = 30,
    rewardPrestige = 1,
    requiredPrestige = 1,
    map = {
        biome = "castle",
        encounters = { min = 5, max = 8, always = { "encounter_elite" } },
        objective = {
            name = "The Reading Room",
            composition = function(ctx)
                local list = { "character_champion" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_bandit" end
                return list
            end,
            win = { type = "killAll" },
        },
        keyCount = 2,
    },
}
