-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The stair guardian of the Pride circle, played over the fight. See
-- conversation_descent_gluttony.lua for what this folder is and why every scene in it is one speaker.
--
-- THE GUARDIAN IS SUPERBIA, THE MORNING STAR now (2026-10-01): Pride's general was reimagined as a fallen
-- archangel, and Sublimitas -- whose voice the two lines below were written in -- moved down to the approach
-- stair. The lines still read for a proud thing that is certain it will measure you, so they stand until the
-- author writes the Morning Star's own (docs/story.md, "Superbia, the Morning Star").

return {
    title = "Superbia, the Morning Star",
    cast  = { "character_general_pride" },

    script = {
        { "character_general_pride", "Show me what you have brought.", tag = 1 },
        { "character_general_pride", "I will know it the moment I see it. I always do. I have not been surprised in a very long time and I would like to be.", tag = 2 },
    },
}
