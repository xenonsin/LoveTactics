-- Capstone for the BATTLEMAGE discipline (fighter x mage) -- data/disciplines/battlemage.lua names
-- this file in `requiredQuests`.
--
-- Signature on show: SPELLSTRIKE -- a cantrip folded into a melee swing (ability_arcane_cleave and
-- utility_spellstrike ship). The exemplar is a spell-and-steel veteran who held a breach alone, and
-- the demonstration is that she does not alternate: she is not a mage who sometimes stabs, she is one
-- motion that is both, and the party's usual read -- close the distance and the caster folds -- is
-- exactly backwards on her.
--
-- Disposition is BOSS, but the Arcanum's kind of boss: she is a decorated veteran holding a ruin the
-- house wants cleared, and she is not wrong about anything except who she still works for.
--
-- GATING: the both-parents rule lives in `Discipline.isUnlocked`, not here -- see the note in
-- data/quests/champions_challenge.lua.
--
-- FIRST PASS. Scenes are not authored, so nothing is named. The veteran wants a bespoke blueprint
-- carrying both halves of the kit; `character_mage` and `character_champion` stand in as two separate
-- bodies, which is precisely the thing the discipline exists to stop being true.
return {
    name = "The Broken Siege",
    description = "The Arcanum broke this siege eleven years ago and left someone in the breach. She " ..
        "is still there, and she is still holding it.",
    difficulty = "Hard",
    sponsor = "arcanum",
    rewardGold = 250,
    rewardRep = 10,
    rewardPrestige = 1,
    requiredPrestige = 4,
    map = {
        biome = "castle",
        encounters = { min = 7, max = 10, always = { "encounter_elite" } },
        objective = {
            name = "The Breach",
            composition = function(ctx)
                local list = { "character_mage", "character_champion" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_knight" end
                return list
            end,
            win = { type = "killAll" },
        },
        keyCount = 1,
    },
}
