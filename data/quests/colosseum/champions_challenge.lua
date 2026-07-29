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
-- GATING, and why naming one quest per parent is EXACT rather than over-strict. A multiclass needs
-- one subclass of each parent before it opens. `requiredQuests` is an all-of list of specific ids and
-- cannot say "any fighter subclass" -- which used to be the argument for leaving the rule entirely to
-- `Discipline.isUnlocked` and gating this quest on a prestige number instead. That argument died when
-- the vendor lines became CHAINS (docs/story.md, "The ten slots"): a line runs in authored order, so
-- reaching a later subclass gate is impossible without having cleared the earlier one. "Any fighter
-- subclass" therefore collapses to "the FIRST fighter subclass gate" -- `warlord_keep` at slot 3, which
-- `blood_in_the_sand` at slot 6 strictly depends on. Naming it locks nobody out; there is no other
-- pair to take.
--
-- So the two ids below are the real prerequisite, stated where a player can see it: this capstone is
-- off the board until both halves are genuinely held, and a multi-key `requiredQuests` shows it
-- LOCKED with its count once the first arrives (models/quest.lua) -- "you have the knight half" is
-- worth putting on the board. `Discipline.isUnlocked` still walks the parents itself, which is now a
-- redundant safety net rather than the only enforcement.
--
-- Prestige is left at the sponsor's own door (the Colosseum opens at 1) so it gates nothing here.
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
    -- Both parents, earned: "slot_03_warlord_keep" is the first fighter subclass gate on its line,
    -- "slot_03_held_position" the first knight. Holding either is impossible without them.
    requiredQuests = { "slot_03_warlord_keep", "slot_03_held_position" },
    requiredPrestige = 1,
    map = {
        biome = "castle",
        encounters = { min = 7, max = 10, always = { "encounter_elite" } },
        objective = {
            name = "The Standing Challenge",
            composition = function(ctx)
                local list = { "character_champion" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_rowan" end
                return list
            end,
            win = { type = "assassinate", target = "character_champion" },
        },
        keyCount = 1,
    },
}
