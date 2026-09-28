-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The stair guardian of the Wrath circle, played over the fight. See
-- conversation_descent_gluttony.lua for what this folder is and why every scene in it is one speaker.
--
-- FUROR, THE THOUSAND-ARMED (2026-09-28, "The Asura of Wrath"): Ira and her Colosseum canon are retired, and
-- the stair belongs to the greatest ascetic there ever was, who spent every bit of what his austerity won him
-- on war. New name, new story, no tie to the Colosseum.
--
-- THE TWO LINES BELOW ARE STILL IRA'S, and they are the author's to rewrite -- a premise change sweeps
-- everything around the spoken lines and touches none of them. Until then a monk-general speaks a champion's
-- words.

return {
    title = "Furor, the Thousand-Armed",
    cast  = { "character_general_wrath" },

    script = {
        { "character_general_wrath", "Do not make it quick. A quick blow is a blow somebody is holding back.", tag = 1 },
        { "character_general_wrath", "I have had a lifetime of being handled. Come and hit me properly.", tag = 2 },
    },
}
