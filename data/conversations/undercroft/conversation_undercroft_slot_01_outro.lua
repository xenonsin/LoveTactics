-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- THE OPENER'S THANKS. See data/conversations/cathedral/conversation_cathedral_slot_01_outro.lua.
return {
    title = "The Third Door",
    cast  = { "undercroft", "character_avatar" },

    script = {
        { "undercroft", "Two keys and a third door. I did wonder how you would take that.", tag = 1 },
        { "character_avatar", "You knew there were three.", tag = 2 },
        { "undercroft", "I knew. I wanted to see what you did about the one I could not give you.", tag = 3 },
        { "undercroft", "Most people come back and tell me the job was short a key. You came back with the box.", tag = 4 },
        { "undercroft", "There is a stair off the markets with no sign on it. Take it. The shelf down there is yours to shop.", tag = 5 },
    },
}
