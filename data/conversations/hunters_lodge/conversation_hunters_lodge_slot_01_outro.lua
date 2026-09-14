-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- PLAYED ON THE FLOOR, over the stag. Kaya joins here: states/game.lua's errand payout recruits
-- `rewardCharacter` immediately before this plays, so the join banner drains onto the end of it.
--
-- IT USED TO BE THE LODGE'S DEBRIEF: antlers set down on a floor in the city, fourteen points counted
-- off, an invitation to the counter. The antlers are the exact thing she is the answer to, so the scene
-- that ends her ask cannot be a trophy being admired.
return {
    title = "The Antlers",
    cast  = { "character_avatar", "character_kaya" },

    script = {
        { "character_kaya", "Fourteen points. The Lodge has been telling itself twelve for nine years.", tag = 30 },
        { "character_kaya", "It came down once. Nothing else in that wood dies today.", tag = 31 },
        { "character_kaya", "I am going further in. I would rather go with you than behind you.", tag = 32 },
    },
}
