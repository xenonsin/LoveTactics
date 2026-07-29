-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "The Shelf and the Sand",
    cast  = { "colosseum", "character_avatar", { id = "character_saber", when = { has = "character_saber" } } },

    script = {
        { "colosseum", "You walked off the sand still breathing, so the shelf is yours -- steel, leathers, the little cruelties that keep a fighter on the card one more week. No house behind you? Good. A house takes a cut. I only take coin.", tag = 1 },
        { "character_avatar", "Then coin is all you'll get.", tag = 2 },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "He says that to every fresh name, {name}. The cut comes later, dressed as a favour -- I've worn three houses' colors and paid each one twice.", tag = 3 },
            { "colosseum", "And yet here you stand, veteran, shilling for a team with nothing behind it.", tag = 4 },
            { "character_saber", "Nothing behind it is the only thing on this sand I have ever trusted. Sell them the good leathers, not the ones you move on the losers.", tag = 5 },
        } },
        { "colosseum", "...The good leathers, then. Win loud, {name}. The crowd keeps a name, and a name is the only thing here I can't sell you -- you earn that one blow by blow.", tag = 6 },
    },
}
