-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The second meeting: an ask already agreed to and not yet run (models/errand.lua's `asked` kind). Short
-- by design. She still will not press -- a companion who nagged on the second meeting would be a
-- different character from the one who refused to take the work unasked on the first.
return {
    title = "The Miller's Ghost",
    cast  = { "character_avatar", "character_amana" },

    script = {
        { "character_amana", "It is still in there. It has hurt no one since you passed, which is not mercy -- there is no one left up here for it to hurt.", tag = 1 },
        { "character_amana", "I will not press you. Ask, and I come.", tag = 2 },
        { "character_avatar", "Now, or on the way past. Choose...", tag = 3, choices = {
            { "Ask her in.", tag = 4, answer = "accept" },
            { "Leave it standing.", tag = 5, answer = "decline" },
        } },
    },
}
