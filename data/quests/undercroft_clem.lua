-- Near the head of the Undercroft's ten (docs/story.md, "The Undercroft", slot 2). How Clem is recruited
-- (character_clem.lua): the Bank keeps a deniable firm of fixers on retainer, and Clem was its finest
-- blade until she broke and turned the craft around -- she now burns the Bank's writs and frees the
-- ruined. The house marks its own retired edge, and hires you to bring her in.
--
-- `rewardCharacter` grants her on the win (Player.recruit refuses a duplicate). You are sent to collect
-- her; the confront (the opening) has her over the debtors she is freeing, and the victory `outro`
-- (clem_joins) is where her plea reveals the machine and she joins -- saying nothing of Aurea yet.
--
-- `boss` on her blueprint keeps the fight honest (no execute, no Charm); her defeat recruits rather than
-- kills, exactly as the Cathedral keeps Amana (data/quests/fallen_confessor.lua) and the Colosseum keeps
-- Saber (data/quests/arena_debut.lua). The reward IS the companion.
return {
    name = "The Retired Blade",
    description = "The Bank's own quiet hand has turned on it -- burning notes, freeing the ruined. The " ..
        "house wants her collected. Bring her in.",
    difficulty = "Normal",
    sponsor = "undercroft",
    rewardGold = 90,
    rewardRep = 30,
    rewardPrestige = 1,
    requiredPrestige = 2,
    rewardCharacter = "character_clem",
    outro = "clem_joins",
    map = {
        biome = "castle",
        encounters = { min = 3, max = 5 },
        objective = {
            name = "The Jubilee",
            composition = function() return { "character_clem" } end,
            opening = "undercroft_clem_confront",
            win = { type = "killAll" },
        },
        keyCount = 1,
    },
}
