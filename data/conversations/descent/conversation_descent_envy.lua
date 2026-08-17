-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The stair guardian of the Envy circle, played over the fight. See
-- conversation_descent_gluttony.lua for what this folder is and why every scene in it is one speaker.
--
-- Livia is the college's masterpiece homunculus, the one that got far enough to WANT, and what she
-- wanted was to be born rather than made. She pacted for humanity and was given the power to copy any
-- human perfectly and never to be one. Her rule reads that as tactics: at the opening bell she takes
-- the shape of your strongest (data/traits/trait_covetous_reflection.lua), which is what the first
-- line is her doing.

return {
    title = "Livia, the Unborn",
    cast  = { "character_general_envy" },

    script = {
        { "character_general_envy", "Hold still. I want to see which of you is worth having.", tag = 1 },
        { "character_general_envy", "I will wear it in a moment, and I will do it perfectly. That has never once been the same as having it.", tag = 2 },
    },
}
