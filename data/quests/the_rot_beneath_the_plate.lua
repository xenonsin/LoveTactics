-- Capstone for the PLAGUE KNIGHT discipline (knight x alchemist) -- data/disciplines/plague_knight.lua
-- names this file in `requiredQuests`.
--
-- Signature on show: CONTAGION -- melee that spreads poison, and standing beside her sickens you
-- (weapon_pestilent_flail and utility_miasmal_plate ship, the Plate as an `incense` charm so the
-- sickness walks with the body wearing it). The exemplar already exists: `character_forsworn_knight`,
-- which is one of the three capstones that costs a quest rather than a quest AND a character.
--
-- The demonstration is the one thing the party has never had to think about -- ADJACENCY AS A COST.
-- Every melee build in the game is trained to close and stay closed, and against her closed is where
-- you rot. The answer is reach, or rotation, or killing her fast, and the board should make the player
-- discover which of the three they actually own.
--
-- Disposition is BOSS. She set the shield down a long time ago and what got in underneath it is the
-- whole joke of the name.
--
-- GATING: the both-parents rule lives in `Discipline.isUnlocked`, not here -- see the note in
-- data/quests/champions_challenge.lua.
--
-- FIRST PASS. Scenes are not authored, so no `intro` / `outro` / `opening` is named.
return {
    name = "The Rot Beneath the Plate",
    description = "The plate is still the order's pattern and still polished. Whatever is inside it " ..
        "has not been a knight for a long while, and the ground she walks is going soft.",
    difficulty = "Hard",
    sponsor = "bastion",
    rewardGold = 250,
    rewardRep = 10,
    rewardPrestige = 1,
    requiredPrestige = 4,
    map = {
        biome = "forest",
        encounters = { min = 7, max = 10, always = { "encounter_forsworn" } },
        objective = {
            name = "The Polished Plate",
            composition = function(ctx)
                local list = { "character_forsworn_knight" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_zombie" end
                return list
            end,
            win = { type = "assassinate", target = "character_forsworn_knight" },
        },
        keyCount = 1,
    },
}
