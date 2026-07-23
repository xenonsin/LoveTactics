-- Near the head of the Arcanum's ten (docs/story.md, "The Arcanum": the companion is earned near the head
-- of her line, on her own). How Gyeom is recruited (character_gyeom.lua): the Arcanum's work is not a
-- secret -- its necromancy and blood magic are done in the open and tolerated because the results are
-- indispensable -- and Gyeom is the one who would not call the human cost acceptable. She obstructed the
-- work and sheltered those marked for it, so the crown-backed Arcanum branded her a dangerous radical and
-- hired you to bring her in.
--
-- `rewardCharacter` grants her on the win (Player.recruit refuses a duplicate, so it is safe on any path
-- that reaches Quest.complete twice). You are sent to TAKE a "weak" mage; the confront (the opening) has
-- her let you think you have her, and the victory `outro` (gyeom_joins) is where she reveals she was never
-- showing her hand, and stays it anyway -- the rhyme the whole line opens on: what is kept back. She gives
-- herself to the only outfit that is not the Arcanum's, and the held join banner folds onto that scene.
--
-- `boss` on her blueprint keeps the fight honest (no execute, no Charm); her defeat recruits rather than
-- kills, exactly as the Cathedral keeps Amana (data/quests/fallen_confessor.lua) and the Colosseum keeps
-- Saber (data/quests/arena_debut.lua). She fights alone: the reward IS the companion.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The Radical",
    description = "The Arcanum has branded one of its own a danger and wants her brought in. She is " ..
        "standing over the ones it marked, and she reads as no trouble at all.",
    difficulty = "Normal",
    sponsor = "arcanum",
    rewardItems = { "weapon_swineherds_wand" },
    rewardGold = 90,
    rewardRep = 30,
    rewardPrestige = 1,
    requiredPrestige = 2,
    rewardCharacter = "character_gyeom",
    -- The victory scene, played over the frozen final frame: she reveals what she never showed, pleads
    -- the cost the realm excuses, and joins. Player.recruit has already added her by the time it runs.
    outro = "gyeom_joins",
    map = {
        biome = "forest",
        encounters = { min = 3, max = 5 }, -- map size scales with this (models/overworld.lua)
        objective = {
            name = "The Branded Mage",
            composition = function() return { "character_gyeom" } end,
            opening = "arcanum_the_radical_confront",
            win = { type = "killAll" },
        },
        keyCount = 1,
    },
}
