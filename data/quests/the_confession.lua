-- Capstone for the INQUISITOR discipline (rogue x priest) -- data/disciplines/inquisitor.lua names
-- this file in `requiredQuests`.
--
-- Signature on show: JUDGMENT -- mark a heretic, then execute the mark with holy damage
-- (weapon_confessors_needle and ability_mark_of_heresy ship). The demonstration is that the mark is
-- the whole weapon: whoever she names is going to die, on schedule, and the fight is about reaching
-- the named person before the schedule does.
--
-- Disposition is BOSS, and the staging is deliberate -- the witch-finder is mid-extraction when the
-- party arrives, which puts the accused on the board as somebody to keep alive rather than as a line
-- of backstory. `assassinate` with `protect` layered under it (Combat.evaluate checks `obj.protect`
-- before the win type, so they compose): cut out the witch-finder, and the person she named lives.
--
-- The Cathedral sponsors this and does not disown her, which is the quiet part: a house that blooded
-- children and called the failures demons has an obvious institutional use for someone whose whole
-- craft is deciding who counts as one (docs/story.md, "The blooding").
--
-- GATING: the both-parents rule lives in `Discipline.isUnlocked`, not here -- see the note in
-- data/quests/champions_challenge.lua.
--
-- FIRST PASS. Scenes are not authored, so nothing is named. The witch-finder wants a bespoke
-- blueprint; `character_priest` stands in, and `character_survivor` is the accused.
return {
    name = "The Confession",
    description = "She has already written down what he is going to say. The extraction is a " ..
        "formality and it is most of the way through.",
    difficulty = "Hard",
    sponsor = "cathedral",
    rewardGold = 250,
    rewardRep = 10,
    rewardPrestige = 1,
    requiredPrestige = 4,
    map = {
        biome = "castle",
        encounters = { min = 7, max = 10, always = { "encounter_elite" } },
        objective = {
            name = "The Witch-Finder",
            composition = function(ctx)
                local list = { "character_priest" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_knight" end
                return list
            end,
            allies = { "character_survivor" },
            win = {
                type = "assassinate",
                target = "character_priest",
                protect = "character_survivor",
            },
        },
        keyCount = 1,
    },
}
