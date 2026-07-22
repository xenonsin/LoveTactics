-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "The Tout on the Concourse",
    cast  = { "character_avatar", "character_knight" },

    script = {
        { "character_knight", "The tunnel to the sand is that way. And a man in a very good coat has been watching you since the gate.", tag = 1 },
        { "character_avatar", "House colors, no house name -- a booking man, here to price the nobody before the crowd does. Choose...", tag = 2, choices = {
            { "Hear his offer.", tag = 3, goto = "offer", effect = { gold = 40 } },
            { "Walk past him to the sand.", tag = 4, goto = "past", effect = { heal = 10 } },
        } },
        { "character_avatar", "...forty in coin to open the card, win or lose, so long as the show is good. He's already written the ending. I take the money anyway.", tag = 5, id = "offer", goto = "sand" },
        { "character_knight", "No handler, no leash, no debt at the door. Whatever happens on that sand is ours alone -- and we walk to it steady.", tag = 6, id = "past", goto = "sand" },
        { "character_knight", "They booked a veteran to open on a team with nothing behind it. Go and make them regret the casting.", tag = 7, id = "sand" },
    },
}
