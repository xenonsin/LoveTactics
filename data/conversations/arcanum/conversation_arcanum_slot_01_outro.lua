-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- THE OPENER'S THANKS. See data/conversations/cathedral/conversation_cathedral_slot_01_outro.lua.
return {
    title = "Still Dripping",
    cast  = { "arcanum", "character_avatar" },

    script = {
        { "arcanum", "Do not open it here. It has been under water since before the city had a wall.", tag = 1 },
        { "character_avatar", "There were four other parties down there digging for it.", tag = 2 },
        { "arcanum", "There were six. Two of them are still down there.", tag = 3 },
        { "arcanum", "You will want a table, light, and someone who can read it. The Arcanum has all three.", tag = 4 },
        { "arcanum", "Our counter is on the markets. Come and use it. That is what it is for.", tag = 5 },
    },
}
