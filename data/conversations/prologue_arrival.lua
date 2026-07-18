-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "The Capital",
    cast  = { { id = "watch", name = "Gate Watch" }, "character_knight" },

    script = {
        { "watch", "Refugees. The city's full and the coin's thin. Want to eat? The Colosseum pays anyone who can bleed for a crowd.", tag = 1 },
        { "character_knight", "Sport, for coin. It is not the war we came to fight.", tag = 2 },
        { "watch", "It's the war you can afford today. Gate's that way. Try not to die on the sand.", tag = 3 },
    },
}
