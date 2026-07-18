-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "Rowan's Lesson",
    cast  = { "character_knight" },

    script = {
        { "character_knight", "To my side, {name}! Take the ground before they do.", tag = 1, id = "move" },
        { "character_knight", "Blade up. You will not talk this one down.", tag = 2, id = "arm" },
        { "character_knight", "Now -- strike, and keep your feet under you.", tag = 3, id = "strike" },
        { "character_knight", "Not that, {name}. Do as I showed you.", tag = 4, id = "nudge" },
        { "character_knight", "Click a lit tile to move there.", tag = 5, id = "move_hint" },
        { "character_knight", "Click your weapon to ready it.", tag = 6, id = "arm_hint" },
        { "character_knight", "Click the demon to strike it.", tag = 7, id = "strike_hint" },
    },
}
