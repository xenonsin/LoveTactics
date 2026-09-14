-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The second meeting: an ask already agreed to and not yet run (models/errand.lua's `asked` kind). Short
-- by design, and hers does not push. She said she would not press, and this is where that is proved.
return {
    title = "The Miller's Ghost",
    cast  = { "character_avatar", "character_amana" },

    script = {
        { "character_amana", "It is still in there. It has hurt nobody since you passed.", tag = 30 },
        { "character_amana", "I will not press you. Ask, and I come.", tag = 31, choices = {
            { "Ask her in.", tag = 32, answer = "accept" },
            { "Leave it standing.", tag = 33, answer = "decline" },
        } },
    },
}
