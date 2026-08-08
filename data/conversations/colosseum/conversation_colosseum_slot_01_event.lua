-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "The Tout on the Concourse",
    cast  = { "character_avatar", "character_rowan" },

    script = {
        { "character_rowan", "The tunnel to the sand is that way. And a man in a very good coat has been watching you since the gate.", tag = 1 },
        { "character_avatar", "House colors, no house name. A booking man, here to price the nobody before the crowd does. Choose...", tag = 2, choices = {
            { "Hear his offer.", tag = 3, goto = "offer", effect = { gold = 40 } },
            { "Walk past him to the sand.", tag = 4, goto = "past", effect = { heal = 10 } },
        } },
        { "character_avatar", "...forty in coin to open the card, win or lose, so long as the show is good. He's already written the ending. I take the money anyway.", tag = 5, id = "offer", goto = "sand" },
        { "character_rowan", "No handler, no leash, no debt at the door. Whatever happens on that sand is ours alone, and we walk to it steady.", tag = 6, id = "past", goto = "sand" },
        { "character_rowan", "They put their opener up against a team with nothing behind it, and look at her: a mismatch in her favor and she's glad of it. Not hungry, not bored, just happy for the fight. No one's read her opening in years. Go be the first.", tag = 7, id = "sand" },
    },
}
