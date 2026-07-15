-- The Colosseum's grind, and the rung between Champion and Legend. `repeatable`, so it stays on the
-- board: the ladder from rank 3 (100 rep) to rank 4 (200 rep) is a hundred points wide, and this is
-- what a fighter runs to close it. Finishing it is what puts Ira within reach.
--
-- No story to it. That is the point -- the arena does not care why you come back.
return {
    name = "Blood in the Sand",
    description = "The card is full and the crowd is paying. Win, and win again.",
    difficulty = "Hard",
    sponsor = "colosseum",
    rewardGold = 180,
    rewardRep = 40,
    rewardPrestige = 1,
    requiredPrestige = 3,
    requiredRep = { vendor = "colosseum", rank = 3 }, -- Champion or better
    repeatable = true,
    map = {
        biome = "castle",
        encounters = { min = 8, max = 12, always = { "elite" } },
        objective = {
            name = "The Card",
            composition = function(ctx)
                local list = { "champion" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "bandit_chief" end
                return list
            end,
            win = { type = "killAll" },
        },
        keyCount = 1,
    },
}
