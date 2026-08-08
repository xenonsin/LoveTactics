-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "A New Formula",
    cast  = { "alchemist", "character_avatar", { id = "character_ren", when = { has = "character_ren" } } },

    script = {
        { "alchemist", "The {discipline}'s Work is unlocked to you, {name}. The Crucible releases its guarded cut for that method. The shelf has more to offer you.", tag = 1 },
        { "character_avatar", "Then it's earned. Show me.", tag = 2 },
        { when = { has = "character_ren" }, script = {
            { "character_ren", "You made this yours honestly. That is rarer here than the gear is. Take it.", tag = 3 },
        } },
    },
}
