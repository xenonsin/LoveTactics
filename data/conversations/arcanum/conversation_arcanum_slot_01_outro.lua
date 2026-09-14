-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- PLAYED ON THE FLOOR, over the book. Gyeom joins here: states/game.lua's errand payout recruits
-- `rewardCharacter` immediately before this plays, so the join banner drains onto the end of it.
--
-- IT USED TO BE THE ARCANUM'S DEBRIEF: the house's reader in the city warning her not to open it there,
-- offering a table and a lamp at their counter. What replaces it is her own count, corrected out loud,
-- which is the one thing she does that nobody else in the roster does.
return {
    title = "Still Dripping",
    cast  = { "character_avatar", "character_gyeom" },

    script = {
        { "character_gyeom", "Do not open it here. It has been under water a very long time.", tag = 30 },
        { "character_gyeom", "Eleven, and then twelve. I was wrong once today and I have written down why.", tag = 31 },
        { "character_gyeom", "I would like to keep walking with people who check their numbers before they open a door.", tag = 32 },
    },
}
