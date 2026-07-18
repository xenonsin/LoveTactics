-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "The Village",
    cast  = { { id = "elder", name = "Village Elder" }, "character_knight" },

    script = {
        { "elder", "Fire on the eastern fields -- demons, real ones, not a soldier's tale! Run, child, run!", tag = 1 },
        { "character_knight", "No one runs while I can hold a blade. Stranger -- you have the look of a fighter. Stand with me.", tag = 2 },
        { "elder", "They serve the Demon Lord. If the capital falls after us, there is nowhere left to run to.", tag = 3 },
        { "character_knight", "Then we hold this lane. Move when I move, strike what I strike. Now -- they come.", tag = 4 },
    },
}
