-- Capstone for the CRUSADER discipline (fighter x priest) -- data/disciplines/crusader.lua names this
-- file in `requiredQuests`.
--
-- Signature on show: SMITE -- holy melee that bites hardest on demons and the undead and heals its
-- wielder on the kill (ability_smite and ability_zealous_charge ship). So the staging is a demon
-- incursion met by a marching column, and the demonstration is the column not slowing down: a
-- crusader gets stronger the deeper into the horde she is, which is the exact inverse of how the
-- party's own front line works.
--
-- Disposition is MENTOR/BOSS and this file takes the mentor reading -- the party marches WITH her.
-- Nothing here is a betrayal; it is the one capstone that is simply a good day's work beside somebody
-- who is better at it than you.
--
-- GATING: `requiredQuests` names the first subclass gate of each parent line, so this capstone does
-- not appear until the player genuinely holds both halves -- see the note in
-- data/quests/colosseum/quest_colosseum_champions_challenge.lua.
--
-- FIRST PASS. Scenes are not authored, so nothing is named. The zealot wants a bespoke blueprint;
-- `character_priest` stands in as the column's own, fighting on the party's side via `allies`.
return {
    name = "The Consecrated March",
    description = "A column is marching into an incursion with a hymn and no reserve line. They have " ..
        "asked if you are coming. They are not waiting for the answer.",
    difficulty = "Hard",
    sponsor = "cathedral",
    rewardItems = { "armor_marching_vow" },
    rewardGold = 250,
    -- Both parents, earned: "quest_colosseum_slot_03" is the first fighter subclass gate on its line,
    -- "quest_cathedral_slot_03" the first priest. Holding either is impossible without them.
    requiredQuests = { "quest_colosseum_slot_03", "quest_cathedral_slot_03" },
    requiredPrestige = 1,
    map = {
        biome = "tundra",
        encounters = { min = 7, max = 10, always = { "encounter_elite" } },
        objective = {
            name = "The Incursion",
            composition = function(ctx)
                local list = { "character_demon_champion" }
                for i = 1, 3 + math.floor((ctx.day or 1) / 2) do list[#list + 1] = "character_demon_grunt" end
                for i = 1, 2 + math.floor((ctx.day or 1) / 3) do list[#list + 1] = "character_demon_imp" end
                return list
            end,
            -- The zealot marches with you. Losing her does not fail the quest -- she would not accept
            -- being the objective, and the discipline is watching her fight, not escorting her.
            allies = { "character_priest" },
            win = { type = "killAll", enemy = "the incursion" },
        },
        keyCount = 1,
    },
}
