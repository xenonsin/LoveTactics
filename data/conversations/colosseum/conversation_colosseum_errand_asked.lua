-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The second meeting: an ask already agreed to and not yet run (models/errand.lua's `asked` kind). Short
-- by design, and hers is the shortest of the six -- a fighter who is contented mid-bout has nothing to
-- add to an offer she already made, and no reason at all to hurry you toward it.
return {
    title = "The Card's Opener",
    cast  = { "character_avatar", "character_saber" },

    script = {
        { "character_saber", "Back already. I haven't moved -- there's nowhere I'd rather be than about to start.", tag = 1 },
        { "character_saber", "Same opening. Same door. Whenever you're ready.", tag = 2 },
        { "character_avatar", "Now, or on the way past. Choose...", tag = 3, choices = {
            { "Take the bout.", tag = 4, answer = "accept" },
            { "Leave her standing.", tag = 5, answer = "decline" },
        } },
    },
}
