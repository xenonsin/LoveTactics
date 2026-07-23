-- Capstone for the ARTIFICER discipline (mage x alchemist) -- data/disciplines/artificer.lua names
-- this file in `requiredQuests`.
--
-- Signature on show: CONSTRUCTS -- autonomous sentries deployed onto the board and told to get on
-- with it (ability_emplace_sentry and ability_overcharge ship; Overcharge Hastes a construct rather
-- than granting it a second turn, which its header admits). The exemplar is a sentry-engine builder,
-- and the demonstration is arithmetic the party cannot match: she is one body and she out-actions a
-- full party, because everything she made also takes a turn.
--
-- Disposition is BOSS/MENTOR and this file takes the boss reading -- she is not defending the foundry
-- from the party so much as continuing to work while they are in it, which is worse.
--
-- GATING: the both-parents rule lives in `Discipline.isUnlocked`, not here -- see the note in
-- data/quests/champions_challenge.lua.
--
-- FIRST PASS. Scenes are not authored, so nothing is named. The builder wants a bespoke blueprint
-- whose grid is the two construct abilities; `character_mage` stands in. The sentries themselves need
-- no stand-in -- `character_ordnance_sentry` and `character_straw_sentry` already ship and are
-- exactly the right bodies.
return {
    name = "The Automaton Foundry",
    description = "She has not stopped working since you came in, and the line has not stopped " ..
        "either. Every turn you spend in here, there is one more of them.",
    difficulty = "Hard",
    sponsor = "alchemist",
    rewardGold = 250,
    rewardRep = 10,
    rewardPrestige = 1,
    requiredPrestige = 4,
    map = {
        biome = "castle",
        encounters = { min = 7, max = 10, always = { "encounter_elite" } },
        objective = {
            name = "The Line",
            composition = function(ctx)
                local list = { "character_mage" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_ordnance_sentry" end
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_straw_sentry" end
                return list
            end,
            win = { type = "assassinate", target = "character_mage" },
        },
        keyCount = 1,
    },
}
