-- Slot 2 of the Bastion's ten. Every other vendor line spends this slot recruiting its companion;
-- the knight's is already sworn to the player from the prologue (data/characters/character_knight.lua),
-- so the Bastion spends it on Rowan herself.
--
-- The beat: she was a squire on a relief column that was ordered to turn back, and it was ordered
-- away from Greywatch. She has spent every year since being the arrival that failed to happen -- which
-- is why she rallied to a burning village that was not hers and swore herself to a stranger standing
-- in it. She will not say which post the column was for. Not yet.
return {
    name = "The Ones Who Turned Back",
    description = "Rowan wants to find three officers of a column that was ordered to turn around. " ..
        "She will not say which column.",
    difficulty = "Easy",
    sponsor = "bastion",
    rewardGold = 100,
    rewardRep = 20,
    rewardPrestige = 1,
    requiredPrestige = 1,
    map = {
        biome = "forest",
        encounters = { min = 5, max = 7 },
        objective = {
            name = "The Last Officer",
            composition = function(ctx)
                local list = { "character_bandit_chief" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_bandit" end
                return list
            end,
            win = { type = "killAll" },
        },
        keyCount = 1,
    },
}
