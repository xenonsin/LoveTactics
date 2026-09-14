-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The second meeting: an ask already agreed to and not yet run (models/errand.lua's `asked` kind). Short
-- by design. Her terms are the one thing she restates, because restating them is what they are for.
return {
    title = "The White Stag",
    cast  = { "character_avatar", "character_kaya" },

    script = {
        { "character_kaya", "It has gone deeper into the wood. It is thinner. That is worse, not better.", tag = 30 },
        { "character_kaya", "Once. My terms have not changed and they are not going to.", tag = 31, choices = {
            { "Take her terms.", tag = 32, answer = "accept" },
            { "Leave the wood.", tag = 33, answer = "decline" },
        } },
    },
}
