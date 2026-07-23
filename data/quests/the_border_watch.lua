-- Capstone for the WARDEN discipline (knight x hunter) -- data/disciplines/warden.lua names this file
-- in `requiredQuests`.
--
-- Signature on show: LOCKDOWN ZONE -- mark ground and everything that enters it is Rooted or Halted
-- (ability_warding_line and ability_march_wardens_standard ship, the latter planting
-- hazard_halting_ground under a `character_field_standard`). The exemplar is a march-warden holding a
-- ford, and the demonstration is that she does not fight the crossing, she PRICES it: the enemy can
-- come, and coming is what kills them.
--
-- Disposition is MENTOR. She is holding the ford whether the party turns up or not, and the quest is
-- standing the watch beside her -- so `hold`, which is the only objective that says "the ground is
-- the point" (the same reading data/quests/held_position.lua takes for the knight).
--
-- GATING: the both-parents rule lives in `Discipline.isUnlocked`, not here -- see the note in
-- data/quests/champions_challenge.lua.
--
-- FIRST PASS. Scenes are not authored, so nothing is named. The march-warden wants a bespoke
-- blueprint carrying the standard; `character_greywatch_captain` stands in on the party's side.
return {
    name = "The Border Watch",
    description = "One warden, one ford, and a crossing that has been getting busier all season. She " ..
        "has not asked for relief. Stand the watch with her.",
    difficulty = "Hard",
    sponsor = "bastion",
    rewardGold = 250,
    rewardRep = 10,
    rewardPrestige = 1,
    requiredPrestige = 4,
    map = {
        biome = "forest",
        encounters = { min = 6, max = 9, always = { "encounter_elite" } },
        objective = {
            name = "The Ford",
            composition = function(ctx)
                local list = { "character_demon_champion" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_demon_grunt" end
                return list
            end,
            allies = { "character_greywatch_captain" },
            -- `region` defaults to "center" for a hold; named because this board IS the crossing.
            -- `duration` is in TICKS (the unit the clock counts and the HUD quotes), not turns.
            win = { type = "hold", region = "center", duration = 30 },
        },
        keyCount = 1,
    },
}
