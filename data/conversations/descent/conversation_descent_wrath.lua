-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The stair guardian of the Wrath circle, played over the fight. See
-- conversation_descent_gluttony.lua for what this folder is and why every scene in it is one speaker.
--
-- CANON (docs/story.md, revised 2026-07-28): Ira was the Perennial's manufactured champion, owned all
-- her life, and she CHOSE the pact -- promised freedom and the strength to seize it, and given an
-- ungovernable rage instead. She must never ask to die: she wanted to be free, not gone. The register
-- is quiet and interior, never operatic, because the horror is a life spent owned.
--
-- The campaign's own confrontation is a forty-line scene written for Saber (see
-- data/conversations/colosseum/conversation_colosseum_slot_10_confront.lua, currently scaffolding).
-- Nothing of it is reached from here and nothing here is a compressed version of it: this is a fighter
-- telling four strangers how she would like to be fought, which is the one thing she has ever been
-- allowed to have an opinion about.

return {
    title = "Ira, the Unappeased",
    cast  = { "character_general_wrath" },

    script = {
        { "character_general_wrath", "Do not make it quick. A quick blow is a blow somebody is holding back.", tag = 1 },
        { "character_general_wrath", "I have had a lifetime of being handled. Come and hit me properly.", tag = 2 },
    },
}
