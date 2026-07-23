-- Capstone for the CHAMPION discipline (fighter x knight) -- data/disciplines/champion.lua names this
-- file in `requiredQuests`, and without it the discipline could never unlock at all.
--
-- The exemplar is the pitch: you do not read that Champion fuses the two shelves, you watch someone do
-- it and then get to build it (docs/disciplines-plan.md). `character_champion` already IS this -- a
-- knight's wall with a fighter's arm -- so this is one of the three capstones that costs a quest
-- rather than a quest AND a character.
--
-- What the fight demonstrates is the signature: RIPOSTE-WALL. She takes the whole party's attention on
-- purpose and answers every striker, so the losing line is the obvious one -- surround her and swing.
-- The board should teach that in about two turns.
--
-- GATING, and the one thing this file cannot say: a multiclass needs one subclass of EACH parent
-- before it opens, and that rule lives in `Discipline.isUnlocked` (models/discipline.lua), which walks
-- the parents itself. A quest can only gate on prestige, sponsor standing and a list of specific quest
-- ids -- there is no way to write "any fighter subclass and any knight subclass" here, and naming two
-- particular ones would lock out a player who took the other pair. So the quest is open on standing
-- and the discipline stays shut until the parents are real. Completing this early is harmless.
--
-- FIRST PASS. Scenes are not authored, so no `intro` / `outro` / `opening` is named (Conversation.play
-- asserts on an unknown id). No `rewardItems`: a discipline's payload is its SHELF, which unlocking
-- opens at the two parent vendors -- the quest is the key, never the prize.
return {
    name = "The Champion's Challenge",
    description = "The league's standing champion keeps an open challenge and has never had to " ..
        "explain the rules. Come at her together. She would prefer it.",
    difficulty = "Hard",
    sponsor = "colosseum",
    rewardGold = 250,
    rewardRep = 10, -- deliberately small: capstones sit outside the ten and must not skew the ladder
    rewardPrestige = 1,
    requiredPrestige = 4,
    map = {
        biome = "castle",
        encounters = { min = 7, max = 10, always = { "encounter_elite" } },
        objective = {
            name = "The Standing Challenge",
            composition = function(ctx)
                local list = { "character_champion" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_knight" end
                return list
            end,
            win = { type = "assassinate", target = "character_champion" },
        },
        keyCount = 1,
    },
}
