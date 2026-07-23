-- Capstone for the POACHER discipline (rogue x hunter) -- data/disciplines/poacher.lua names this file
-- in `requiredQuests`.
--
-- Signature on show: SNARE-EXECUTE -- the trap sets up the kill, and the knife bites harder on
-- anything Rooted (weapon_poachers_kris and ability_bolas ship). The exemplar is a bounty-jumper, and
-- the demonstration is order of operations: she never opens with the knife, she opens with the ground,
-- and by the time anyone is in reach of her the fight has already been decided somewhere else.
--
-- Disposition is RECRUIT. She has been taking the Lodge's marks out from under it -- which is
-- poaching, and which is also the only reason half those bounties got closed at all -- and she is
-- entirely willing to work for whoever is paying next.
--
-- GATING: the both-parents rule lives in `Discipline.isUnlocked`, not here -- see the note in
-- data/quests/champions_challenge.lua.
--
-- FIRST PASS. Scenes are not authored, so nothing is named, and no `rewardCharacter` is set: the
-- trapper needs a blueprint of her own before she can join anything. `character_bandit_chief` stands
-- in, and the traps that are the entire point of her are not on the board at all.
return {
    name = "The Marked Quarry",
    description = "Somebody has been closing the Lodge's entries before the Lodge's own runners get " ..
        "there, and collecting on them. She was waiting at your mark before you were.",
    difficulty = "Hard",
    sponsor = "hunters_lodge",
    rewardGold = 250,
    rewardRep = 10,
    rewardPrestige = 1,
    requiredPrestige = 4,
    map = {
        biome = "forest",
        encounters = { min = 7, max = 10, always = { "encounter_wolf" } },
        objective = {
            name = "The Jumped Bounty",
            composition = function(ctx)
                local list = { "character_bandit_chief" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_archer" end
                list[#list + 1] = "character_dire_bear"
                return list
            end,
            win = { type = "assassinate", target = "character_bandit_chief" },
        },
        keyCount = 1,
    },
}
