-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "A Question",
    cast  = { "bastion", "character_knight" },

    script = {
        { "character_knight", "I want to ask the order a question.", tag = 1 },
        { "bastion", "Ask it.", tag = 2 },
        { "character_knight", "Did you know.", tag = 3 },
        { "bastion", "...", tag = 4 },
        { "bastion", "Take the quest, Sworn.", tag = 5 },
    },
}
