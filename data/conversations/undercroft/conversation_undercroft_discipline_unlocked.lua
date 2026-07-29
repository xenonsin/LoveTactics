-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "Off the Book",
    cast  = { "undercroft", "character_avatar", { id = "character_clem", when = { has = "character_clem" } } },

    script = {
        { "undercroft", "The {discipline}'s trade is yours now, {name}. The firm keeps stock off the open book for a hand that reaches it -- and you reached it. Quietly, mind.", tag = 1 },
        { "character_avatar", "Then it's earned. Show me.", tag = 2 },
        { when = { has = "character_clem" }, script = {
            { "character_clem", "Took me years to get shown that rack. You did it faster. Don't get sloppy with it.", tag = 3 },
        } },
    },
}
