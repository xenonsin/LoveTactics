-- Capstone for the DUELIST discipline (fighter x rogue) -- data/disciplines/duelist.lua names this file
-- in `requiredQuests`.
--
-- Signature on show: DUEL STANCE, an escalating bonus while locked one-on-one with a single foe
-- (trait_duelists_poise, which ships). So the staging is the mechanic: a blade-for-hire has a table in
-- the back of a tavern and takes all comers ONE AT A TIME, and she is not being sporting -- one at a
-- time is the condition under which she cannot lose. The party's answer is to refuse the format.
--
-- Disposition is RECRUIT (docs/disciplines-plan.md): she is beaten, she is delighted about it, and she
-- signs on. Nothing about her is villainous and the fight should not be staged as a killing.
--
-- GATING: the both-parents rule lives in `Discipline.isUnlocked`, not here -- see the note in
-- data/quests/champions_challenge.lua, which explains why a quest cannot express it.
--
-- FIRST PASS. Scenes are not authored, so nothing is named, and no `rewardCharacter` is set: the
-- swaggering blade needs a blueprint of her own before she can join anything (she is one of the ~17
-- new exemplar NPCs the plan budgets). `character_bandit_chief` stands in, which is exactly the wrong
-- register and should not survive her getting a real one.
return {
    name = "The Tavern Duel",
    description = "She has a table at the back and takes all comers, one at a time, and has never " ..
        "lost. One at a time is the reason.",
    difficulty = "Normal",
    sponsor = "colosseum",
    rewardGold = 250,
    rewardRep = 10,
    rewardPrestige = 1,
    requiredPrestige = 4,
    map = {
        biome = "castle",
        encounters = { min = 6, max = 8 },
        objective = {
            name = "The Table at the Back",
            composition = function(ctx)
                local list = { "character_bandit_chief" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_bandit" end
                return list
            end,
            win = { type = "assassinate", target = "character_bandit_chief" },
        },
        keyCount = 1,
    },
}
