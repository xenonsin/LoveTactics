-- Capstone for the NINJA discipline (rogue x mage) -- data/disciplines/ninja.lua names this file in
-- `requiredQuests`, and names Kaen as its exemplar.
--
-- Signature on show: SHADOWCLONE -- decoys on the board, a blink between them, and a bearer who
-- vanishes out of sight (ability_mirror_image and ability_vanishing_strike ship). The demonstration is
-- the cleanest in the slate because it is a puzzle rather than a stat check: most of what the party
-- can see is not there, and every turn spent hitting a copy is a turn Kaen spends behind them.
--
-- Disposition is BOSS, and Kaen is the one marquee name in the multiclass table (the rest are
-- placeholders -- docs/disciplines-plan.md's open calls). Whatever she is finally for, she should not
-- be a hireling: the fight reads best if the party never finds out who sent her.
--
-- GATING: the both-parents rule lives in `Discipline.isUnlocked`, not here -- see the note in
-- data/quests/champions_challenge.lua.
--
-- FIRST PASS. Scenes are not authored, so nothing is named. Kaen wants her own blueprint carrying both
-- abilities -- the clones are the character and a stand-in cannot express her at all;
-- `character_bandit_chief` is a placeholder and nothing more.
return {
    name = "The Shadowless",
    description = "Four of her came down the corridor and none of them cast a shadow. Three are " ..
        "wrong. You get one guess per turn.",
    difficulty = "Hard",
    sponsor = "undercroft",
    rewardGold = 250,
    rewardRep = 10,
    rewardPrestige = 1,
    requiredPrestige = 4,
    map = {
        biome = "castle",
        encounters = { min = 7, max = 10, always = { "encounter_elite" } },
        objective = {
            name = "Kaen",
            composition = function(ctx)
                local list = { "character_bandit_chief" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_bandit" end
                return list
            end,
            win = { type = "assassinate", target = "character_bandit_chief" },
        },
        keyCount = 1,
    },
}
