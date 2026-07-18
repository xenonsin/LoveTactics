-- The Colosseum's entry bout, and the prologue's climax (states/prologue.lua): the boss on the sand
-- is Saber, the house's gatekeeper, and besting her recruits her (see docs/story.md and
-- data/characters/character_saber.lua). Its purpose is to be the first quest a new player finishes --
-- the fight that gives the nameless survivor a name.
return {
    name = "Debut on the Sand",
    description = "The Colosseum offers you a bout. Win it, and they will remember your name.",
    difficulty = "Easy",
    sponsor = "colosseum",
    rewardGold = 60,
    rewardRep = 25,
    rewardPrestige = 1,
    requiredPrestige = 1,
    map = {
        biome = "castle",
        encounters = { min = 2, max = 4 }, -- map size scales with this (models/overworld.lua)
        objective = {
            name = "The Gatekeeper",
            -- Saber, plus a single bandit hand so a two-unit prologue party is tested but not
            -- overwhelmed. She is the objective; the bandit is a wall, not the point.
            composition = function() return { "character_saber", "character_bandit" } end,
            win = { type = "killAll" },
        },
        keyCount = 0,
    },
}
