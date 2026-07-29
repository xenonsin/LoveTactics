-- Near the head of the Cathedral's ten (docs/story.md, "The other seven": the companion is earned near
-- the head of her line, on her own). How Amana is recruited (character_amana.lua): the Cathedral brands
-- its own -- a Confessor who sheltered the oblates it wanted reclaimed, and would not hand them back -- as
-- fallen, and hires you to purge her. She stands over the one she is protecting and will not yield.
--
-- `rewardCharacter` grants her on the win (Player.recruit refuses a duplicate, so it is safe on any path
-- that reaches Quest.complete twice). You are sent to TAKE her; you best her instead, and she gives
-- herself to the only outfit that was never the faith's hand -- the rhyme the whole line opens on, and
-- closes on when Lust offers her back to herself (data/quests/cathedral/quest_cathedral_slot_10.lua).
--
-- `boss` on her blueprint keeps the fight honest (no execute, no Charm); her defeat recruits rather than
-- kills, exactly as the Colosseum debut keeps Saber (data/quests/colosseum/quest_colosseum_slot_01.lua). She fights alone: the
-- reward IS the companion, and a second body beside her would only be a wall in the way of it.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The Fallen Confessor",
    description = "The Cathedral has branded one of its own fallen and wants her purged. She is standing " ..
        "over someone, and she will not step aside.",
    difficulty = "Normal",
    sponsor = "cathedral",
    rewardItems = { "weapon_renewal_staff" },
    rewardGold = 90,
    rewardRep = 30,
    rewardPrestige = 1,
    requiredQuests = { "quest_cathedral_slot_01" }, -- slot 2: the line runs in order
    requiredPrestige = 1,
    rewardCharacter = "character_amana",
    -- The plea. She is bested, stays your hand, and tells you what the rite actually does before you
    -- collect -- then joins. Player.recruit has already run by the time this plays, so the join banner
    -- folds onto the scene. Note what she still believes about the Saint: that is slot 7's to break.
    outro = "conversation_cathedral_slot_02_join",
    map = {
        biome = "forest",
        encounters = { min = 3, max = 5 }, -- map size scales with this (models/overworld.lua)
        objective = {
            name = "The Branded Saint",
            composition = function() return { "character_amana" } end,
            opening = "conversation_cathedral_slot_02_confront",
            win = { type = "killAll" },
        },
        keyCount = 1,
    },
}
