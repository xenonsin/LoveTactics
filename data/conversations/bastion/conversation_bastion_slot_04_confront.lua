-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- OFFER 4 OF 10, and THE ONE WHERE THE VOICE ARRIVES (docs/temptation.md). Three worldly bargains have
-- already been taken or refused; this is the first that is recognisably the same sentence somebody
-- said to Acedia fifteen years ago, and the man saying it knows that and says so. He is not possessed
-- and nothing supernatural happens: he is a forsworn Bastion captain repeating an offer he took, in
-- the words it was made in. The Crown never appears in this game. It only ever arrives in a mouth the
-- chapter already had (docs/story.md: there is nothing under the crown).
--
-- IT IS IN THE CONFRONT, NOT THE OUTRO, and that is load-bearing twice over. The outro
-- (conversation_bastion_slot_04_outro.lua) already ends on Rowan saying "He wasn't lying about a fact,
-- though, was he. He asked me a question" -- which was written before this system existed and is now
-- literally about the choice the player just made. And it means the player agrees with him and then
-- kills him anyway, which is the most honest thing this line does.
--
-- Slot 10's offer is in ITS confront for a different and mechanical reason: Quest.complete resolves the
-- ledger before the outro plays, so an offer in a slot-10 outro would be counted after the line had
-- already been decided. See models/temptation.lua.
return {
    title = "An Entry on the List",
    cast  = { "character_forsworn_captain", "character_rowan", "character_avatar" },

    script = {
        { "character_forsworn_captain", "You've the look. Bastion. Sworn, by the shield.", tag = 1 },
        { "character_forsworn_captain", "Whose name do you carry, then?", tag = 2 },
        { "character_rowan", "Acedia's.", tag = 3 },
        { "character_forsworn_captain", "Of course it is. They are still handing her out.", tag = 4 },
        { "character_forsworn_captain", "Ask them where she is buried. Go on. Not what she did. Where she is buried.", tag = 5 },
        { "character_rowan", "At Greywatch. Under the gate she died holding.", tag = 6 },
        { "character_forsworn_captain", "Is she.", tag = 7 },
        { "character_forsworn_captain", "I have the rest of the list. Where all of us went, what names we took. It is worth more to your order than my head is.", tag = 8 },
        { "character_forsworn_captain", "You can have it. I want one thing said back to me first, and I want it said by her.", tag = 9 },
        { "character_forsworn_captain", "Hold until relieved. Nobody is coming. Nobody was ever coming, for her or for me or for you.", tag = 10 },
        { "character_forsworn_captain", "So set it down. That is all it has ever been. You set it down and nothing happens.", tag = 11 },
        { "character_forsworn_captain", "That is not my line. Somebody put it to her in that order, word for word, and she is under a gate now and I am out here on a road, and the difference between us is four days.", tag = 12 },
        { "character_avatar", "...", tag = 13, choices = {
            { "\"Keep your list.\"", tag = 14, goto = "refuse" },
            { "\"I'll take the list. Say what you like.\"", tag = 15, goto = "took", effect = { gold = 200, take = "bastion" } },
            { "\"Rowan. Answer him.\"", tag = 16, goto = "with", effect = { gold = 200, take = "bastion", press = "bastion" } },
        } },
        { "character_forsworn_captain", "No. Of course not. Neither did I, the first four times.", tag = 17, id = "refuse", goto = "after" },
        { "character_forsworn_captain", "Written down and paid for. You are easier than she was.", tag = 18, id = "took", goto = "after" },
        { "character_rowan", "...Nobody came.", tag = 19, id = "with" },
        { "character_rowan", "I was on that road. I know exactly how far we got.", tag = 20 },
        { "character_forsworn_captain", "There. That was not so hard, and it did not cost you anything at all.", tag = 21 },
        { "character_forsworn_captain", "It never does. That is what nobody tells you about it.", tag = 22, id = "after" },
    },
}
