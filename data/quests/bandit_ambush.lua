-- Quest blueprint. `requiredPrestige` gates when the quest appears on the
-- board; `Quest.available(prestige)` filters on it.
return {
    name = "Bandit Ambush",
    description = "Raiders have blocked the north road. Clear them out.",
    difficulty = "Easy",
    rewardGold = 50,
    requiredPrestige = 1,
    -- Overworld map generated when the quest starts (see models/overworld.lua).
    map = {
        biome = "forest",
        cols = 31, rows = 21,
        encounters = { min = 4, max = 6 }, -- rivers come from the biome
        -- The objective encounter's battle: its enemy roster (composition) and win
        -- condition (win). `win.type` defaults to "killAll" if omitted.
        objective = {
            name = "Bandit Chief",
            composition = function(ctx)
                local list = { "bandit_chief" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "bandit" end
                return list
            end,
            win = { type = "assassinate", target = "bandit_chief" },
        },
        keyCount = 0,
    },
}
