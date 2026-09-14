-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The second meeting: an ask already agreed to and not yet run (models/errand.lua's `asked` kind). Short
-- by design, and the pressure in it is the crate rather than her.
return {
    title = "The Consignment",
    cast  = { "character_avatar", "character_ren" },

    script = {
        { "character_ren", "Still here. So is the crate, and so is the crew sitting on it.", tag = 30 },
        { "character_ren", "It keeps. It should not have to keep.", tag = 31, choices = {
            { "Go in with her.", tag = 32, answer = "accept" },
            { "Leave it lying.", tag = 33, answer = "decline" },
        } },
    },
}
