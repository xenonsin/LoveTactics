-- Capstone for the VANGUARD discipline (knight x rogue) -- data/disciplines/vanguard.lua names this
-- file in `requiredQuests`.
--
-- Signature on show: BREACH -- knockback that strips guard and armour, opening a line rather than
-- holding one (ability_shieldbreak and ability_pry_open ship). The exemplar is a shieldbreaker
-- turncoat, and the demonstration is a knight's kit pointed the wrong way round: everything the
-- Bastion taught her about walls, used to take one apart from the inside.
--
-- Disposition is BOSS, and the fiction is the Bastion's own nightmare said plainly -- a gate opened
-- from within, which is the exact sentence the sloth line spends ten quests on (docs/story.md,
-- Greywatch). This is a small, deliberate echo, not a plot connection: she is nobody's agent.
--
-- GATING: the both-parents rule lives in `Discipline.isUnlocked`, not here -- see the note in
-- data/quests/champions_challenge.lua.
--
-- FIRST PASS. Scenes are not authored, so nothing is named. The turncoat wants a bespoke blueprint;
-- `character_forsworn_captain` stands in and is close enough in register to be misleading -- she is
-- not forsworn, she is for hire.
return {
    name = "The Salted Gate",
    description = "Somebody took the gate apart from the inside, and they did it the way the order " ..
        "teaches. They are still in there, salting the ground behind them.",
    difficulty = "Hard",
    sponsor = "bastion",
    rewardGold = 250,
    rewardRep = 10,
    rewardPrestige = 1,
    requiredPrestige = 4,
    map = {
        biome = "castle",
        encounters = { min = 7, max = 10, always = { "encounter_elite" } },
        objective = {
            name = "The Shieldbreaker",
            composition = function(ctx)
                local list = { "character_forsworn_captain" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_bandit_chief" end
                return list
            end,
            win = { type = "assassinate", target = "character_forsworn_captain" },
        },
        keyCount = 1,
    },
}
