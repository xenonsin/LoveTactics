-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "The Roadside Shrine",
    cast  = { "character_avatar", "character_knight" },

    script = {
        { "character_knight", "A wayside shrine, still standing where everything around it burned.", tag = 1 },
        { "character_avatar", "Someone tended it to the last. It feels wrong to walk straight past. Choose...", tag = 2, choices = {
            { "Kneel and pray for the road ahead.", tag = 3, goto = "pray", effect = { heal = 12 } },
            { "Take the traveller's offering left at its foot.", tag = 4, goto = "take", effect = { grant = "consumable_mana_potion" } },
        } },
        { "character_avatar", "...steadier. Whatever waits up the road, my hands are steadier for it.", tag = 5, id = "pray", goto = "leave" },
        { "character_knight", "Flasks, wrapped against the damp -- left for whoever came after. That is us now. Carry them.", tag = 6, id = "take" },
        { "character_knight", "The capital, then. Keep moving.", tag = 7, id = "leave" },
    },
}
