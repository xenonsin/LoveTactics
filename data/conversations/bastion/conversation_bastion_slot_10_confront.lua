-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- OFFER 10 OF 10, MADE IN A GENERAL'S OWN VOICE (docs/temptation.md). Nine mouths have carried it this
-- far; this is the woman it was originally made to, making it herself, to the person standing behind
-- the knight she is trying to relieve.
--
-- IT HAS TO BE IN THE CONFRONT AND THAT IS MECHANICAL, not taste. Quest.complete resolves this line's
-- ledger the instant the objective clears (`endsLine` on data/quests/bastion/quest_bastion_slot_10.lua),
-- and the outro plays after that -- so an offer authored into the outro would be counted AFTER the
-- thing it is supposed to decide. The confront runs before the first turn of the fight, which puts the
-- last word in before the sum is taken. See models/temptation.lua.
--
-- Acedia was already written to make this offer -- the quest file's own header says so, and Rowan's
-- refusal ("I know what mine is worth. I chose it.") was authored long before this system existed. All
-- that is added here is the player finally being asked too, and the possibility that Rowan does not
-- get to say her line.
return {
    title = "Acedia, the Unrelieved",
    cast  = { "character_general_sloth", "character_rowan", "character_avatar" },

    script = {
        { "character_general_sloth", "Fifteen years of knights have held that line because they can say my name over their shields.", tag = 1 },
        { "character_general_sloth", "Take it from them and the Watch empties tonight. Not in a year. Tonight.", tag = 2 },
        { "character_general_sloth", "I have done more for that line as a lie than I ever did with a shield in my hands. Put your weapon down and think about it honestly, which is more than the order ever managed.", tag = 3 },
        { "character_rowan", "...You're right.", tag = 4 },
        { "character_general_sloth", "Yes.", tag = 5 },
        { "character_rowan", "I have thought about it every mile of that road and I cannot answer you. Perhaps it does empty. Perhaps I am about to cost the line more than you ever did.", tag = 6 },
        { "character_rowan", "But you never chose that post. It was issued to you. And when it came due you set it down.", tag = 7 },
        { "character_rowan", "Then you spent fifteen years making that the truth about every post there has ever been. So that yours would stop being a thing you did.", tag = 12 },
        { "character_general_sloth", "You. Girl. You have someone standing at your back.", tag = 8 },
        { "character_general_sloth", "Look at them properly. No post is worth holding. That includes theirs.", tag = 9 },
        { "character_general_sloth", "You have been letting her put things down for a while now. I can hear it in how she is standing.", tag = 13 },
        { "character_general_sloth", "So finish it. Relieve her. She has done enough and there was never anybody coming, and you have known that longer than she has.", tag = 14 },
        { "character_avatar", "...", tag = 15, choices = {
            { "\"She's not yours to relieve.\"", tag = 16, goto = "refuse" },
            { "\"You're not wrong. It changes nothing here.\"", tag = 17, goto = "took", effect = { gold = 300 } },
            { "\"Rowan. You've done enough.\"", tag = 18, goto = "with", effect = { gold = 300 } },
        } },
        { "character_general_sloth", "No. Nobody's ever is. That is what makes it so easy.", tag = 19, id = "refuse", goto = "hold" },
        { "character_general_sloth", "Then you have agreed with me and come anyway. How very much like the order.", tag = 20, id = "took", goto = "hold" },
        { "character_general_sloth", "...There it is.", tag = 21, id = "with" },
        { "character_rowan", "...", tag = 22 },
        { "character_rowan", "Yes.", tag = 23 },
        { "character_rowan", "All right.", tag = 24 },
        { "character_general_sloth", "Come and stand over here, child. You have been on that road a very long time.", tag = 25, goto = "end" },
        { "character_rowan", "I know what mine is worth.", tag = 10, id = "hold" },
        { "character_rowan", "I chose it.", tag = 11 },
    },
}
