-- Capstone for the SKIRMISHER discipline (fighter x hunter) -- data/disciplines/skirmisher.lua names
-- this file in `requiredQuests`.
--
-- Signature on show: HIT-AND-RUN -- strike, then reposition (trait_skirmishers_momentum, which ships,
-- pays a damage bonus for having moved). The exemplar is a raider outrider and the whole quest is that
-- rule read as a scenario: they will not hold ground, they will not trade, and a party that plants
-- itself and waits to be attacked will be whittled down over twenty turns without ever landing a
-- clean blow. You have to make them stand still.
--
-- Disposition is BOSS. The outriders are raiders and there is nothing to negotiate.
--
-- GATING: the both-parents rule lives in `Discipline.isUnlocked`, not here -- see the note in
-- data/quests/champions_challenge.lua.
--
-- FIRST PASS. Scenes are not authored, so nothing is named. The outrider captain wants a bespoke
-- blueprint built around movement -- high speed, a mount, no reason to ever be adjacent;
-- `character_bandit_chief` and `character_archer` stand in and are far too willing to stay put.
return {
    name = "The Running Fight",
    description = "The outriders have been bleeding the road for a month and have never once been " ..
        "where the column expected. They will not stand. Make them.",
    difficulty = "Hard",
    sponsor = "hunters_lodge",
    rewardGold = 250,
    rewardRep = 10,
    rewardPrestige = 1,
    requiredPrestige = 4,
    map = {
        biome = "forest",
        encounters = { min = 7, max = 10, always = { "encounter_elite" } },
        objective = {
            name = "The Outrider Captain",
            composition = function(ctx)
                local list = { "character_bandit_chief" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_archer" end
                return list
            end,
            win = { type = "assassinate", target = "character_bandit_chief" },
        },
        keyCount = 1,
    },
}
