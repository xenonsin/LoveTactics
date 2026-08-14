-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The OVERRULE scene of data/quests/colosseum/quest_colosseum_slot_02.lua, and it is not an outro: it
-- plays IN the fight, over the board, at the moment the win would have been declared
-- (states/battle.lua's battle.fireOverrule). The player has just put the last carded killer down and
-- every refugee is still standing. The far gate is open and IRA IS ALREADY ON THE SAND behind the text.
--
-- SHE IS A UNIT, NOT A REPORT. That is the whole difference from the scene this replaces, which had the
-- avatar calling the action like a man at a window: "She is walking at the refugees." "They are down.
-- All of them are down." "I am on my back." None of that belongs here any more, because the player is
-- about to watch every bit of it happen on the board and then take a turn against her. So this scene
-- says only the things the board cannot: who she is, that she is not an opponent, and that the house
-- sent her on purpose. The moment it closes the refugees are cut down (the overrule's `fell`), and the
-- fight resumes with the party facing her.
--
-- IT ENDS BEFORE THE ANSWER. Nobody in here gets to say what to do about her, because there is nothing
-- to say and the player is about to find that out with their own hands. Rowan's last line is an order
-- that cannot be obeyed in time; Saber's is the law of the house being broken in front of her.
--
-- SHE DOES NOT SPEAK, and she is not in the cast; slot 7 is her first word.
--
-- THE HOUSE MEANT ALL OF IT. The promoter is not surprised and is not panicking. He sold a night of
-- blood, the crowd is owed one, and when the player's win threatened to send them home short he had
-- the gate opened. His lines are the coldest in the scene and must stay that way: the house is not
-- losing control of Ira here, it is USING her, and slot 7 is where the player finds out what using her
-- costs. Do not let him beg for her to be taken off. He wants the sand cleared.
--
-- What it costs Saber: everyone walks off the sand is her one law, and it is about to break twice in
-- front of her, the second time under her own feet. It is the exact shape of the thing that broke her
-- once already (slot 10: "they died anyway; someone else did it while she stood there"), and this is
-- the seed that slot pays off.
--
-- The join banner is held across this scene (`deferJoins`, states/battle.lua): a recruit has no
-- business in the scene before everyone dies. It lands in the waking afterwards
-- (data/conversations/colosseum/conversation_colosseum_slot_02_join.lua).
return {
    title = "The Padded Card",
    cast  = { "colosseum", "character_avatar", { id = "character_saber", when = { has = "character_saber" } }, { id = "character_rowan", when = { has = "character_rowan" } } },

    script = {
        { "character_avatar", "The killers are down. Every one of these people is still standing.", tag = 1 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "The elder is up, {name}. We have carried that one out of two fires now.", tag = 2 },
        } },
        { "colosseum", "Well fought. The house has no complaint with you.", tag = 3 },
        { "colosseum", "The crowd paid for a night, though. The house always gives them the night.", tag = 4 },
        { "colosseum", "Open the far gate.", tag = 5 },
        { "character_avatar", "Who is that?", tag = 6 },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "That is the patron of this house. Put your sword down, {name}.", tag = 7 },
            { "character_saber", "She is not an opponent. Nobody cards her against anyone.", tag = 8 },
        } },
        { "colosseum", "Her own hand, and on an opener. You will not see that twice in a life.", tag = 9 },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "Everyone walks off the sand. That is the one law this place has ever kept.", tag = 10 },
        } },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "She is going for them. Get in front of them, all of you!", tag = 11 },
        } },
    },
}
