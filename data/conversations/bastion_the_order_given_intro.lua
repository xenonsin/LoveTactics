-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "What It Stopped Reading",
    cast  = { "bastion", "character_knight" },

    script = {
        { "bastion", "The archive keeps everything. Including what it stopped reading.", tag = 1 },
        { "character_knight", "Greywatch. The relief order that was cut for it. I want the date on the seal.", tag = 2 },
        { "bastion", "The archivist will not give you that.", tag = 3 },
        { "character_knight", "I know. That's why I'm bringing {name} and not a requisition.", tag = 4 },
    },
}
