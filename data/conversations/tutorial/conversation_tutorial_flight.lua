-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "The Open Road",
    cast  = { "character_rowan" },

    script = {
        { "character_rowan", "Walk to the chest ahead -- use WASD, the arrow keys, or click a tile.", tag = 1, id = "move_hint" },
        { "character_rowan", "Open your loadout to see what you found.", tag = 2, id = "loadout_hint" },
        { "character_rowan", "{select} an item in your stash to equip it to a hero.", tag = 3, id = "equip_hint" },
    },
}
