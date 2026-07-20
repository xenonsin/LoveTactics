-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "Another Name",
    cast  = { "bastion", "character_knight" },

    script = {
        { "bastion", "Another name off the roll. There is always another.", tag = 1 },
        { "character_knight", "How long is the roll?", tag = 2 },
        { "bastion", "Longer than last season.", tag = 3 },
    },
}
