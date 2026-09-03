-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The second meeting: an ask already agreed to and not yet run (models/errand.lua's `asked` kind). Short
-- by design. She is the party's tempo rather than its shield, and the one pressure she applies is the
-- honest one -- every day the door stays shut is another day somebody up top is still owing.
return {
    title = "The Vault Door",
    cast  = { "character_avatar", "character_clem" },

    script = {
        { "character_clem", "Still counting. He has not moved, and neither have the names in there.", tag = 1 },
        { "character_clem", "Every day that door stays shut is a day somebody up top still owes. Whenever you like. Not slower than that.", tag = 2 },
        { "character_avatar", "Now, or on the way past. Choose...", tag = 3, choices = {
            { "Open it.", tag = 4, answer = "accept" },
            { "Leave it standing.", tag = 5, answer = "decline" },
        } },
    },
}
