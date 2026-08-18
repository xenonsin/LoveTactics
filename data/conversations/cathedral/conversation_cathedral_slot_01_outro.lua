-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- THE OPENER'S THANKS. This house posted its first job on a floor and somebody went and did it, so this
-- is where the Cathedral learns your name. It is also the door: running this errand is what puts the
-- shelf in the market (models/errand.lua), and the greeting waiting there picks up from these lines.
return {
    title = "The Mill Is Quiet",
    cast  = { "cathedral", "character_avatar" },

    script = {
        { "cathedral", "It is quiet. I stood at that gate an hour and it did not start again.", tag = 1 },
        { "character_avatar", "He was still turning the wheel. He did not know the water was gone.", tag = 2 },
        { "cathedral", "They rarely do. That is the whole of the work, and most people will not go and do it.", tag = 3 },
        { "cathedral", "We keep a counter in the markets. Come to it. You have bought the right to be sold to.", tag = 4 },
    },
}
