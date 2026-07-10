-- Hunter's Lodge. The Lodge calls it a cull. The stag's herd calls it something else.
return {
    name = "The Sacred Stag",
    description = "A white stag walks the deep wood. The Lodge wants its antlers on their wall.",
    difficulty = "Normal",
    sponsor = "hunters_lodge",
    rewardGold = 130,
    rewardRep = 30,
    rewardPrestige = 1,
    requiredPrestige = 1,
    map = {
        biome = "forest",
        cols = 39, rows = 27,
        encounters = { min = 6, max = 9 },
        objective = {
            name = "The White Stag",
            composition = function(ctx)
                local list = { "stag_beast" }
                for i = 1, 1 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "boar" end
                if (ctx.prestige or 1) >= 3 then list[#list + 1] = "wolf_alpha" end
                return list
            end,
            win = { type = "assassinate", target = "stag_beast" },
        },
        keyCount = 0,
    },
}
