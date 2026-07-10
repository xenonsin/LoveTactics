return {
    name = "Siege of Warlord's Keep",
    description = "The Warlord once fought under the Colosseum's banner. They want him brought back, or brought down.",
    difficulty = "Hard",
    sponsor = "colosseum",
    rewardGold = 300,
    rewardRep = 60,
    rewardPrestige = 2,
    requiredPrestige = 3,
    -- Overworld map generated when the quest starts (see models/overworld.lua).
    map = {
        biome = "castle",
        cols = 51, rows = 35,
        encounters = { min = 10, max = 14, always = { "elite", "elite" } },
        objective = {
            name = "The Warlord",
            composition = function(ctx)
                local list = { "warlord" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "champion" end
                return list
            end,
            win = { type = "assassinate", target = "warlord" },
        },
        keyCount = 2,
    },
}
