-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "The Deeper Wood",
    cast  = { "hunters_lodge", "character_avatar", { id = "character_kaya", when = { has = "character_kaya" } } },

    script = {
        { "hunters_lodge", "You walk the {discipline}'s trail now, {name}. The Lodge sets out gear for the ones who get this far -- it is yours to draw.", tag = 1 },
        { "character_avatar", "Then it's earned. Show me.", tag = 2 },
        { when = { has = "character_kaya" }, script = {
            { "character_kaya", "That path knows when to stop. Take the kit. Remember the lesson with it.", tag = 3 },
        } },
    },
}
