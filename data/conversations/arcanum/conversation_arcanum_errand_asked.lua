-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The second meeting: an ask already agreed to and not yet run (models/errand.lua's `asked` kind). Short
-- by design, and she spends it correcting her own count, which is the character in one beat.
return {
    title = "The Reading Room",
    cast  = { "character_avatar", "character_gyeom" },

    script = {
        { "character_gyeom", "Twelve now. One of them came back with a friend, so my count was wrong when I gave it to you.", tag = 30 },
        { "character_gyeom", "I will be on this step. The book is not going anywhere.", tag = 31, choices = {
            { "Take the room.", tag = 32, answer = "accept" },
            { "Leave the book.", tag = 33, answer = "decline" },
        } },
    },
}
