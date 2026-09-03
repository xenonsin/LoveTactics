-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The second meeting: an ask already agreed to and not yet run (models/errand.lua's `asked` kind). Short
-- by design -- she has introduced herself, and the only thing left is the choice. Her correction is the
-- character: the count changed, so she says the old one was wrong rather than that the room got harder.
return {
    title = "The Reading Room",
    cast  = { "character_avatar", "character_gyeom" },

    script = {
        { "character_gyeom", "Twelve now. One of them came back with a friend, which means my count was wrong when I gave it to you and I would rather you heard that from me.", tag = 1 },
        { "character_gyeom", "I will be on this step. The book is not going anywhere, and apparently neither am I.", tag = 2 },
        { "character_avatar", "Now, or on the way past. Choose...", tag = 3, choices = {
            { "Take the room.", tag = 4, answer = "accept" },
            { "Leave it standing.", tag = 5, answer = "decline" },
        } },
    },
}
