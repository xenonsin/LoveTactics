-- Near the head of the Crucible's ten (docs/story.md, "The Crucible", slot 2). How Ren is recruited
-- (character_ren.lua): the college chases the Great Work -- making a person from base matter -- and dumps
-- the hollow discards as "corrupted things from the wild." Ren gives the Work away free and shelters the
-- discards, so the college brands her a heretic and hires you to bring her in.
--
-- `rewardCharacter` grants her on the win (Player.recruit refuses a duplicate). You are sent to take a
-- counterfeiter; the confront (the opening) has her stand over the ones she sheltered, and the victory
-- `outro` (ren_joins) is where her plea reveals the manufacture and she joins -- saying nothing of Livia
-- yet.
--
-- `boss` on her blueprint keeps the fight honest (no execute, no Charm); her defeat recruits rather than
-- kills, exactly as the Cathedral keeps Amana (data/quests/fallen_confessor.lua) and the Colosseum keeps
-- Saber (data/quests/arena_debut.lua). The reward IS the companion.
return {
    name = "The Counterfeiter",
    description = "The Crucible has branded one of its own a heretic -- she gives the Work away for free " ..
        "and hides what it discards. Bring her in.",
    difficulty = "Normal",
    sponsor = "alchemist",
    rewardGold = 90,
    rewardRep = 30,
    rewardPrestige = 1,
    requiredPrestige = 2,
    rewardCharacter = "character_ren",
    outro = "ren_joins",
    map = {
        biome = "castle",
        encounters = { min = 3, max = 5 },
        objective = {
            name = "The Heretic Alchemist",
            composition = function() return { "character_ren", "character_homunculus" } end,
            opening = "crucible_the_counterfeiter_confront",
            win = { type = "killAll" },
        },
        keyCount = 1,
    },
}
