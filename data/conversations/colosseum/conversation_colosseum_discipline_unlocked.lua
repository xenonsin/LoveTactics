-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "A New Card",
    cast  = { "colosseum", "character_avatar", { id = "character_saber", when = { has = "character_saber" } } },

    script = {
        { "colosseum", "The {discipline}'s work is on your card now, {name}. The stable stocks for the fighters who reach it -- and you reached it. Spend, and spend well.", tag = 1 },
        { "character_avatar", "Then it's earned. Show me.", tag = 2 },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "Knew you had it in you. That gear's sharper than the house lets most touch -- go on, kit up.", tag = 3 },
        } },
    },
}
