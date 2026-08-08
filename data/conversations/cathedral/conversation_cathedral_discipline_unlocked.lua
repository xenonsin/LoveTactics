-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "What the Faith Keeps",
    cast  = { "cathedral", "character_avatar", { id = "character_amana", when = { has = "character_amana" } } },

    script = {
        { "cathedral", "The {discipline}'s calling is open to you, {name}. What the Cathedral kept back for that path is on the shelf. Take what serves.", tag = 1 },
        { "character_avatar", "Then it's earned. Show me.", tag = 2 },
        { when = { has = "character_amana" }, script = {
            { "character_amana", "The Light gives what is earned, and you earned this. Carry it gently.", tag = 3 },
        } },
    },
}
