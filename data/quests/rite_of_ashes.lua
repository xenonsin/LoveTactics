-- The Cathedral's second contract, and the first quest gated on reputation rather than prestige:
-- it stays off the board until the player is an Acolyte (rank 2) with the Cathedral. See
-- `requiredRep` in models/quest.lua.
--
-- A `survive` objective: hold the consecrated ground while the rite burns down.
return {
    name = "The Rite of Ashes",
    description = "The rite takes eight turns and cannot be hurried. Something in the dark knows it.",
    difficulty = "Hard",
    sponsor = "cathedral",
    rewardGold = 220,
    rewardRep = 45,
    rewardPrestige = 1,
    requiredPrestige = 2,
    requiredRep = { vendor = "cathedral", rank = 2 }, -- Acolyte or better
    map = {
        biome = "forest",
        cols = 39, rows = 27,
        encounters = { min = 6, max = 9, always = { "elite" } },
        objective = {
            name = "The Consecration",
            composition = function(ctx)
                local list = { "miller_ghost" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "wolf_grunt" end
                return list
            end,
            win = { type = "survive", turns = 8 },
        },
        keyCount = 1,
    },
}
