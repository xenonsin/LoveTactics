-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "The Open Road",
    cast  = { "character_knight" },

    script = {
        { "character_knight", "Walk to the chest ahead -- use WASD, the arrow keys, or click a tile.", tag = 1, id = "move_hint" },
        { "character_knight", "Open your loadout to see what you found.", tag = 2, id = "loadout_hint" },
        { "character_knight", "{select} an item in your stash to equip it to a hero.", tag = 3, id = "equip_hint" },
    },
}
