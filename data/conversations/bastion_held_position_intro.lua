-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "Nothing Behind It",
    cast  = { "bastion", "character_knight" },

    script = {
        { "bastion", "A watchpost east of the river. There is nothing behind it worth defending -- the villages moved off that land twenty years ago.", tag = 1 },
        { "bastion", "The garrison has been told, in writing, that they may stand down.", tag = 2 },
        { "character_knight", "And they haven't.", tag = 3 },
        { "bastion", "They have not.", tag = 4 },
        { "character_knight", "Good.", tag = 5 },
        { "character_knight", "Come and stand with them, {name}. You have been taking my word for what the order is. Today you can watch it done properly.", tag = 6 },
    },
}
