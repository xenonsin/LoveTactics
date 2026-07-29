-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "A Further Working",
    cast  = { "arcanum", "character_avatar", { id = "character_gyeom", when = { has = "character_gyeom" } } },

    script = {
        { "arcanum", "You have opened the {discipline}'s discipline, {name}. The Arcanum unseals what it holds for that study -- the shelf is longer for you now.", tag = 1 },
        { "character_avatar", "Then it's earned. Show me.", tag = 2 },
        { when = { has = "character_gyeom" }, script = {
            { "character_gyeom", "There is always more to learn on that road. Good. Take only what you will practise.", tag = 3 },
        } },
    },
}
