-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- THE SECOND MEETING, and it is not the first. Reached by walking back up to a companion whose ask has
-- already been agreed to and not yet run (Errand.posting's `asked` kind), which happens whenever an open
-- posting is seated again on a later run. Short on purpose: she has introduced herself, the choice is
-- the only thing left to make, and having her say her name twice is the failure this scene exists to
-- stop (models/errand.lua's Errand.postingScene).
return {
    title = "The Consignment",
    cast  = { "character_avatar", "character_ren" },

    script = {
        { "character_ren", "Still here. So is the crate, and so is whatever the college is calling it this week.", tag = 1 },
        { "character_ren", "It keeps. It should not have to keep.", tag = 2 },
        { "character_avatar", "Now, or on the way past. Choose...", tag = 3, choices = {
            { "Go in with her.", tag = 4, answer = "accept" },
            { "Leave it standing.", tag = 5, answer = "decline" },
        } },
    },
}
