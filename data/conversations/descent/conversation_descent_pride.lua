-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The stair guardian of the Pride circle, played over the fight. See
-- conversation_descent_gluttony.lua for what this folder is and why every scene in it is one speaker.
--
-- Sublimitas pacted for perfect comprehension: she has only to glance at a working to know it and cast
-- it herself. Perfection is a ceiling, and her rule is that ceiling as tactics -- a single-target spell
-- aimed at her is answered and unravelled, because she already knows it
-- (data/traits/trait_counter_magic.lua). The counterplay is not to show her your hand.
--
-- She is certain and she is bored, and the second is the part that is hers rather than the pact's.

return {
    title = "Sublimitas, the Unequalled",
    cast  = { "character_general_pride" },

    script = {
        { "character_general_pride", "Show me what you have brought.", tag = 1 },
        { "character_general_pride", "I will know it the moment I see it. I always do. I have not been surprised in a very long time and I would like to be.", tag = 2 },
    },
}
