-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- THE OPENER'S THANKS. See data/conversations/cathedral/conversation_cathedral_slot_01_outro.lua for
-- what this scene is for: the first job a house posts on a floor, and the door it opens.
return {
    title = "The Antlers",
    cast  = { "hunters_lodge", "character_avatar" },

    script = {
        { "hunters_lodge", "Set them down. No, on the floor. I want to see how they stand.", tag = 1 },
        { "hunters_lodge", "Fourteen points. I have been telling them twelve for nine years.", tag = 2 },
        { "character_avatar", "It walked out of the fog and stopped. It had a look at us first.", tag = 3 },
        { "hunters_lodge", "It always does. That is why it is on the wall and not in a pot.", tag = 4 },
        { "hunters_lodge", "The Lodge keeps a counter in the markets. It is open to you now. Ask for me by the wall.", tag = 5 },
    },
}
