-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- THE OPENER'S THANKS. See data/conversations/cathedral/conversation_cathedral_slot_01_outro.lua.
return {
    title = "Intact",
    cast  = { "alchemist", "character_avatar" },

    script = {
        { "alchemist", "Straw is dry. Seals are whole. Nothing has gone off inside it.", tag = 1 },
        { "character_avatar", "The crate never left our hands.", tag = 2 },
        { "alchemist", "Then you are the first. Four consignments have come off that road this season and three came back as a smell.", tag = 3 },
        { "alchemist", "The college will be told it was recovered intact. They will not be told by whom, because they would try to hire you.", tag = 4 },
        { "alchemist", "Come to the Crucible instead. Our counter is on the markets and it is open to you.", tag = 5 },
    },
}
