-- Capstone for the APOTHECARY discipline (priest x alchemist) -- data/disciplines/apothecary.lua names
-- this file in `requiredQuests`, and names Ren as its exemplar.
--
-- This is the odd one of the twenty-one, and deliberately so: Apothecary is what Ren ALREADY is --
-- she mends before she strikes -- so the exemplar is a companion the player has been fielding for
-- half the campaign, and the "first meet" beat every other capstone runs is unavailable. What
-- replaces it is a COMPANION QUEST, which is the reuse that docs/disciplines-plan.md flags as a
-- choice rather than a bake (see its open calls: keep companions as roots only, or let a few double
-- as exemplars).
--
-- Signature on show: LENT VITALITY -- elixirs that heal and lend the drinker's own numbers out
-- (ability_transfusion and utility_coveted_blood ship). The demonstration is Ren's whole thesis made
-- into a scenario rather than a stat: she runs a clinic through a fight she did not start, and what
-- the party is protecting is not a position, it is her ability to keep giving things away.
--
-- `killAll` with `protect` layered under it (Combat.evaluate checks `obj.protect` before the win type,
-- so they compose): clear the ward, and the people in it live. Note the deliberate rhyme with
-- data/quests/what_ren_kept.lua at slot 8 of the Crucible's ten -- that quest is where she learns to
-- RECEIVE, and this one only works properly after it. They are not gated on each other (the
-- discipline tree has enough gates), but a player who runs them in the other order gets the weaker
-- version.
--
-- GATING: the both-parents rule lives in `Discipline.isUnlocked`, not here -- see the note in
-- data/quests/champions_challenge.lua. This one has a second, unexpressible prerequisite too: it
-- wants Ren RECRUITED, and a quest cannot gate on party membership. She is recruited at slot 2 of the
-- Crucible's line, well before prestige 4, so in practice it holds.
--
-- FIRST PASS. Scenes are not authored, so nothing is named. Ren fights on the party's side via
-- `allies` -- `character_ren` ships and is the right body, which makes this one of the three capstones
-- that costs a quest rather than a quest AND a character.
return {
    name = "The Open Ward",
    description = "Ren has a ward full of people who are not going anywhere, and the fighting has " ..
        "come to the street outside. She is not leaving and she is not going to stop working.",
    difficulty = "Hard",
    sponsor = "alchemist",
    rewardGold = 250,
    rewardRep = 10,
    rewardPrestige = 1,
    requiredPrestige = 4,
    map = {
        biome = "castle",
        encounters = { min = 6, max = 9, always = { "encounter_elite" } },
        objective = {
            name = "The Ward",
            composition = function(ctx)
                local list = { "character_bandit_chief" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_bandit" end
                return list
            end,
            allies = { "character_ren", "character_survivor", "character_survivor" },
            win = { type = "killAll", protect = "character_survivor" },
        },
        keyCount = 1,
    },
}
