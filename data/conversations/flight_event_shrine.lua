-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "The Roadside Shrine",
    cast  = { "character_avatar", "character_knight" },

    script = {
        { "character_knight", "A wayside shrine, still standing where everything around it burned.", tag = 1 },
        { "character_avatar", "Someone tended it to the last -- and cut a healer's rite into the stone. It feels wrong to walk straight past. Choose...", tag = 2, choices = {
            { "Kneel and learn the rite by heart.", tag = 3, goto = "pray", effect = { heal = 12, grant = "ability_heal" } },
            { "Copy it down and press on.", tag = 4, goto = "take", effect = { grant = "ability_heal" } },
        } },
        { "character_avatar", "...steadier. And I know now how to close a wound that is not my own.", tag = 5, id = "pray", goto = "leave" },
        { "character_knight", "A mending rite, left for whoever came after. That is us now. Carry it.", tag = 6, id = "take" },
        { "character_knight", "The capital, then. Keep moving.", tag = 7, id = "leave" },
    },
}
