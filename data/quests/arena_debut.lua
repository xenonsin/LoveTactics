-- The Colosseum's entry bout: no map tricks, no objective target, just the sand and whoever
-- is standing on it. Its purpose is to be the first quest a new player finishes.
return {
    name = "Debut on the Sand",
    description = "The Colosseum offers you a bout. Win it, and they will remember your name.",
    difficulty = "Easy",
    sponsor = "colosseum",
    rewardGold = 60,
    rewardRep = 25,
    rewardPrestige = 1,
    requiredPrestige = 1,
    map = {
        biome = "castle",
        encounters = { min = 2, max = 4 }, -- map size scales with this (models/overworld.lua)
        objective = {
            name = "The Bout",
            composition = function(ctx)
                local list = { "champion" }
                for i = 1, 1 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "bandit" end
                return list
            end,
            win = { type = "killAll" },
        },
        keyCount = 0,
    },
}
