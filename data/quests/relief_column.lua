-- Slot 1 of the Bastion's ten (docs/story.md, "The Bastion: sloth, designed"). The introduction, and
-- the line's thesis stated in miniature: a column that has to ARRIVE.
--
-- An escort, built on the `protect` loss condition rather than a win type (see data/quests/
-- caravan_road.lua and Combat.evaluate) -- the fight is an ordinary killAll, and the wagon master
-- dying loses it outright. That is the whole doctrine of the Watch reduced to one board: holding is
-- not the job, someone else surviving is.
--
-- Rowan recites "hold until relieved" here, flat, the way you recite something you were issued. She
-- is also unaccountably tense about a routine contract, and the line spends nine more quests
-- explaining why.
return {
    name = "The Relief Column",
    description = "A Bastion column is overdue at a border post. The Bastion would like it to arrive.",
    difficulty = "Easy",
    sponsor = "bastion",
    rewardGold = 80,
    rewardRep = 20,
    rewardPrestige = 1,
    requiredPrestige = 1,
    rewardItems = { "utility_relief_horn" },
    map = {
        biome = "forest",
        encounters = { min = 4, max = 6 },
        objective = {
            name = "The Overdue Column",
            composition = function(ctx)
                local list = { "character_bandit_chief" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_bandit" end
                return list
            end,
            allies = { "character_caravan_master" }, -- fights beside the party, runs itself
            win = { type = "killAll", protect = "character_caravan_master" },
        },
        keyCount = 0,
    },
}
