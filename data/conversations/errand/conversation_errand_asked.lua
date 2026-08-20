-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- THE WORK A HOUSE ASKED FOR, found where it said it would be. The asking already happened over a
-- counter (models/vendor_visit.lua) and the shop has been naming the floor ever since, so this scene
-- has less to tell the player than its `found` sibling does -- what it is here for is the choice. A
-- floor is not obliged to be spent the way it was planned: the company arrives lighter than it left,
-- and taking the stair instead leaves this standing exactly where it is.
--
-- Speaks for all seven houses: `{house}` is the name and `{posting}` is the quest's own description,
-- both set on the player for the scene's duration (states/game.lua's askErrand).
return {
    title = "The Work Asked For",
    cast  = { "character_avatar", { id = "character_rowan", when = { has = "character_rowan" } } },

    script = {
        { "character_avatar", "This is the one {house} sent us for.", tag = 1 },
        { "character_avatar", "{posting}", tag = 2 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "Their shelf moves when it is done and not before. It keeps until we come back for it, {name}, and so does the stair.", tag = 3 },
        } },
        { "character_avatar", "Now, or on the way past. Choose...", tag = 4, choices = {
            { "Take it on.", tag = 5, answer = "accept" },
            { "Leave it standing.", tag = 6, answer = "decline" },
        } },
    },
}
