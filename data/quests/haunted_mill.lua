return {
    name = "The Haunted Mill",
    description = "Something stalks the old mill after dark. The Cathedral wants it laid to rest.",
    difficulty = "Normal",
    sponsor = "cathedral",
    rewardGold = 120,
    rewardRep = 30,
    rewardPrestige = 1,
    requiredPrestige = 1,
    -- Overworld map generated when the quest starts (see models/overworld.lua).
    map = {
        biome = "forest",
        encounters = { min = 6, max = 9, always = { "encounter_elite" } },
        objective = {
            name = "The Miller's Ghost",
            composition = function(ctx)
                local list = { "character_miller_ghost" }
                if (ctx.prestige or 1) >= 2 then list[#list + 1] = "character_wolf_grunt" end
                return list
            end,
            win = { type = "assassinate", target = "character_miller_ghost" },
        },
        keyCount = 2,
    },
}
