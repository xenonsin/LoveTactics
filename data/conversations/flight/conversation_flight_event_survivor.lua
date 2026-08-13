-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "A Voice from the Brush",
    cast  = { "character_avatar", "character_rowan" },

    script = {
        { "character_rowan", "Hold. Someone's in the brush. Hurt, and trying not to be heard.", tag = 1 },
        { "character_avatar", "Easy. We're not with the things that did this. Choose...", tag = 2, choices = {
            { "Ask which way the demons went.", tag = 3, goto = "ask", effect = { flag = "met_the_survivor", grant = "ability_mark_target" } },
            { "Share what little we carry, and press on.", tag = 4, goto = "give", effect = { flag = "met_the_survivor", grant = "ability_assayers_eye" } },
        } },
        { "character_avatar", "...north, along the ridge, in numbers. Good. We take the low road. And she gave you the tell: where a demon's guard runs thin, if you mark it before the strike.", tag = 5, id = "ask", goto = "part" },
        { "character_rowan", "Nothing to spare but thanks, and she gave that freely. An assayer's lens, pressed on you in kind: look through it and a demon's satchel keeps nothing back.", tag = 6, id = "give", goto = "part" },
        { "character_rowan", "An apothecary, before the fires. Then the capital: reach the walls.", tag = 7, id = "part" },
    },
}
