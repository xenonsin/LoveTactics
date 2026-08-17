-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The stair guardian of the Lust circle, played over the fight. See
-- conversation_descent_gluttony.lua for what this folder is and why every scene in it is one speaker.
--
-- Her rule is that she takes what you HELD BACK -- every blow draws off the stamina and mana the target
-- was hoarding (data/traits/trait_rapture.lua) -- so the counterplay is to spend. She says it outright.
-- A boss naming her own rule is the reference material's habit and it costs nothing here: a descent
-- party has no tooltip on her and no ten quests of warning.

return {
    title = "Luxuria, the Unbidden",
    cast  = { "character_general_lust" },

    script = {
        { "character_general_lust", "You are holding something back. For the bottom, or for whatever you have decided is worse than me.", tag = 1 },
        { "character_general_lust", "I will have it either way. It is the only thing I have ever been able to do.", tag = 2 },
    },
}
