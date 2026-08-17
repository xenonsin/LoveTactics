-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The stair guardian of the Sloth circle, played over the fight. See
-- conversation_descent_gluttony.lua for what this folder is and why every scene in it is one speaker.
--
-- Acedia held the greatest post on the Watch and is the doctrine's namesake. When the Bastion wrote her
-- post off she negotiated -- her life and her company's, for the gate -- and the land beyond it paid.
-- The sin is not the cowardice; it is the fifteen years since, spent walking the line telling knights
-- that no post is worth holding, with the authority of a name the order still reads off its shields as
-- a martyr's. So she offers the way out first, and she means it.

return {
    title = "Acedia, the Unrelieved",
    cast  = { "character_general_sloth" },

    script = {
        { "character_general_sloth", "You want the stair behind me. You could turn round instead. Nobody down here would hold it against you.", tag = 1 },
        { "character_general_sloth", "I held a post once. Nobody came. You will find out what I found out, and it will take you about fifteen years.", tag = 2 },
    },
}
