-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The second meeting: an ask already agreed to and not yet run (models/errand.lua's `asked` kind). Short
-- by design. What is urgent to her is not the vault, it is the names in it.
return {
    title = "The Vault Door",
    cast  = { "character_avatar", "character_clem" },

    script = {
        { "character_clem", "Still counting. He has not moved, and neither have the names in there.", tag = 30 },
        { "character_clem", "Every day that door stays shut is a day somebody still owes. Whenever you like. Not slower than that.", tag = 31, choices = {
            { "Open it.", tag = 32, answer = "accept" },
            { "Walk away.", tag = 33, answer = "decline" },
        } },
    },
}
