-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The second meeting: an ask already agreed to and not yet run (models/errand.lua's `asked` kind). Short
-- by design, and the terms do not soften -- she set them once and a hunter who renegotiated while the
-- wood got worse would be the opposite of what her name means.
return {
    title = "The White Stag",
    cast  = { "character_avatar", "character_kaya" },

    script = {
        { "character_kaya", "It moved north while you were away. It is thinner. That is worse, not better -- a thin one eats sooner.", tag = 1 },
        { "character_kaya", "Once. My terms have not changed and they are not going to.", tag = 2 },
        { "character_avatar", "Now, or on the way past. Choose...", tag = 3, choices = {
            { "Take her terms.", tag = 4, answer = "accept" },
            { "Leave it standing.", tag = 5, answer = "decline" },
        } },
    },
}
