-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "Debut on the Sand",
    cast  = { "knight", "mage", { id = "priest", when = { has = "priest" } }, "colosseum" },

    script = {
        { "colosseum", "So. Fresh blood for the sand. The crowd does love a debut -- win or die.", tag = 1 },
        { "knight", "We came to fight, not to be entertainment.", tag = 2 },
        { "colosseum", "Here they are the same thing. Tell me -- why should the arena remember your name?", tag = 3, choices = {
            { "\"Because we fight for coin.\"", tag = 4, goto = "coin" },
            { "\"Because we fight for honor.\"", tag = 5, goto = "honor" },
        } },
        { "colosseum", "Honest, at least. The purse is yours if you live.", tag = 6, id = "coin", goto = "ready" },
        { "colosseum", "Honor. The crowd will cheer it and forget it by morning.", tag = 7, id = "honor" },
        { when = { has = "priest" }, script = {
            { "priest", "Then let us be quick about it. The Light is watching, even here.", tag = 8, id = "ready" },
            { "mage", "Watching, and unimpressed. Open the gate.", tag = 9 },
        } },
    },
}
