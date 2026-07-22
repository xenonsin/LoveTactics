-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "A Voice from the Brush",
    cast  = { "character_avatar", "character_knight" },

    script = {
        { "character_knight", "Hold. Someone's in the brush -- hurt, and trying not to be heard.", tag = 1 },
        { "character_avatar", "Easy. We're not with the things that did this. Choose...", tag = 2, choices = {
            { "Ask which way the demons went.", tag = 3, goto = "ask", effect = { flag = "met_the_survivor", grant = "ability_disarm" } },
            { "Share what little we carry, and press on.", tag = 4, goto = "give", effect = { grant = "ability_disarm" } },
        } },
        { "character_avatar", "...north, along the ridge, in numbers. Good. We take the low road, then.", tag = 5, id = "ask", goto = "part" },
        { "character_knight", "Nothing to spare but thanks -- and she gave that freely.", tag = 6, id = "give", goto = "part" },
        { "character_knight", "An apothecary, before the fires. She pressed a vial of solvent on you in kind -- splash it and a demon cannot grip its blade. Then the capital: reach the walls.", tag = 7, id = "part" },
    },
}
