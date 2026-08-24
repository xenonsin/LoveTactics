-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- OFFER 9 OF 10 (docs/temptation.md), and the last one before Acedia makes it herself. It is put by
-- the forty-one, alive, still in the order's forms, still disciplined -- and it is the ACTUAL terms
-- rather than an echo of them, because these are the people who took it. Nothing is dressed up. They
-- name the price and they are not lying about any part of it.
--
-- Her three closing lines are the line's whole thesis and they are unchanged: the sentence is the
-- same, and the one thing you can do about a sentence is be somewhere the day it costs something.
-- Which is exactly what the player has spent nine quests deciding, one small sum at a time.
return {
    title = "One Mark Each",
    cast  = { "character_rowan", "character_forsworn_captain", "character_avatar" },

    script = {
        { "character_rowan", "Forty-one people said it in the same breath and then walked out through the gate.", tag = 1 },
        { "character_rowan", "It is the same sentence, {name}. Word for word. There is nothing you can do to a sentence to stop that happening to it.", tag = 2 },
        { "character_forsworn_captain", "Forty-two, if you want it. She has never once closed the roll.", tag = 7 },
        { "character_forsworn_captain", "It is not a trick and there is no small print. You keep your name, your company and your kit. You keep her.", tag = 8 },
        { "character_forsworn_captain", "You put down the one thing you are carrying that is costing you something, and you go on exactly as you are.", tag = 9 },
        { "character_avatar", "...", tag = 10, choices = {
            { "\"Forty-one. It stays forty-one.\"", tag = 11, goto = "refuse" },
            { "\"What's the fee?\"", tag = 12, goto = "took", effect = { gold = 500 } },
            { "\"Rowan. Ask her what she put down.\"", tag = 13, goto = "with", effect = { gold = 500 } },
        } },
        { "character_forsworn_captain", "As you like. We are four miles up that road when you change your mind.", tag = 14, id = "refuse", goto = "after" },
        { "character_forsworn_captain", "There is no fee. That is the part nobody believes until afterwards.", tag = 15, id = "took", goto = "after" },
        { "character_rowan", "What did you put down. Say it plainly.", tag = 16, id = "with" },
        { "character_forsworn_captain", "Nothing, knight. That is what I have been telling you.", tag = 17 },
        { "character_forsworn_captain", "I set down a thing that was already not doing anything, and I have been warm every winter since.", tag = 18 },
        { "character_rowan", "...", tag = 19, id = "after" },
        { "character_rowan", "No. There is one thing.", tag = 4 },
        { "character_rowan", "You can be somewhere the day it costs something.", tag = 5 },
        { "character_rowan", "Let's go. She is four miles up that road and she has been waiting fifteen years to be told she was right.", tag = 6 },
    },
}
