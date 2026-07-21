-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "A Voice from the Brush",
    cast  = { "character_avatar", "character_knight" },

    script = {
        { "character_knight", "Hold. Someone's in the brush -- hurt, and trying not to be heard.", tag = 1 },
        { "character_avatar", "Easy. We're not with the things that did this. Choose...", tag = 2, choices = {
            { "Ask which way the demons went.", tag = 3, goto = "ask", effect = { flag = "met_the_survivor" } },
            { "Share what little we carry, and press on.", tag = 4, goto = "give", effect = { grant = "utility_torch" } },
        } },
        { "character_avatar", "...north, along the ridge, in numbers. Good. We take the low road, then.", tag = 5, id = "ask", goto = "part" },
        { "character_knight", "They pressed a torch on us for the kindness -- said the low road is dark by dusk. Take it.", tag = 6, id = "give" },
        { "character_knight", "Go carefully. The capital's walls still stand -- reach them.", tag = 7, id = "part" },
    },
}
