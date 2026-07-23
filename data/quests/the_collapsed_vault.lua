-- Capstone for the SABOTEUR discipline (rogue x alchemist) -- data/disciplines/saboteur.lua names this
-- file in `requiredQuests`.
--
-- Signature on show: PLANTED CHARGES -- place quietly, detonate on cue (ability_set_charge and
-- utility_ghost_kit ship; the Kit detonates a chosen tile rather than a previously-placed charge,
-- which its header admits is an approximation). The exemplar is a demolitions ghost, and the
-- demonstration is that she has already won before the party arrives: the vault is coming down on a
-- timer she set, and nothing in the party's kit can argue with a building.
--
-- So the objective is `reach` (region "far") and not a kill. That is the point of the slot -- the one
-- capstone where the exemplar is not an obstacle, she is a countdown, and the correct response to a
-- saboteur is to be somewhere else. She gets out too. She is unbothered.
--
-- Disposition is RECRUIT: she will happily work for whoever hires her, and she has no quarrel with a
-- party that had the sense to run.
--
-- GATING: the both-parents rule lives in `Discipline.isUnlocked`, not here -- see the note in
-- data/quests/champions_challenge.lua.
--
-- FIRST PASS. Scenes are not authored, so nothing is named, and no `rewardCharacter` is set -- the
-- ghost needs a blueprint before she can join. `character_bandit` and `character_crucible_golem` are
-- the vault's own guard, standing in for what is left running around a building coming apart.
return {
    name = "The Collapsed Vault",
    description = "Someone set charges in the footings four hours ago and left. The vault is coming " ..
        "down whatever anyone does about it. Be outside when it does.",
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
            name = "The Way Out",
            composition = function(ctx)
                local list = { "character_crucible_golem" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_bandit" end
                return list
            end,
            win = { type = "reach", region = "far" },
        },
        keyCount = 1,
    },
}
