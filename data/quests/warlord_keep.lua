--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "Siege of Warlord's Keep",
    description = "The Warlord once fought under the Colosseum's banner. They want him brought back, or brought down.",
    difficulty = "Hard",
    sponsor = "colosseum",
    rewardItems = { "weapon_bellfounders_hammer", "armor_rally_coat" },
    rewardGold = 300,
    rewardRep = 60,
    rewardPrestige = 2,
    requiredPrestige = 3,
    -- Overworld map generated when the quest starts (see models/overworld.lua).
    map = {
        biome = "castle",
        encounters = { min = 10, max = 14, always = { "encounter_elite", "encounter_elite" } },
        objective = {
            name = "The Warlord",
            composition = function(ctx)
                local list = { "character_warlord" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_champion" end
                return list
            end,
            win = { type = "assassinate", target = "character_warlord" },
        },
        keyCount = 2,
    },
}
