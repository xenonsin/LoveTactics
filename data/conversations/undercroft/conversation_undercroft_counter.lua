-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- THE COUNTER SCENE for this house: what the keeper says on the way in, ending on the DESK -- the one
-- node whose choices are the rooms behind this door (models/counter.lua).
--
-- THE DESK NODE'S ID IS "desk" AND IT MUST NEVER CARRY A `when`. Closing a room comes back HERE rather
-- than to the top of the scene (Conversation.play's `startAt`), so this is the one line in the file that
-- always exists -- a desk resolved out of its own scene would open onto the greeting forever.
--
-- EVERY ROOM LINE IS GATED ON ITS OWN OFFER (`when = { offer = ... }`), which reads the same answer the
-- DOOR out on the plaza was drawn from (models/offer.lua). A line that could disagree with its own card
-- would offer a room the player cannot reach, or hide one they can. The Exit line is never gated.
--
-- TWO SHELVES BEHIND ONE DOOR, and they are not the same shop. The town's own counter is here -- plain
-- kit, three rolled rows a day, any class -- beside the fence's own ladder, and each keeps its own
-- vendor so neither overwrites the other (models/offer.lua, data/buildings/undercroft.lua).
return {
    title = "The Undercroft",
    cast  = { "undercroft" },

    script = {
        { "undercroft", "Everything on this floor belonged to somebody else once. Some of it twice.", tag = 1 },
        { "undercroft", "Which pile?", tag = 2, id = "desk", choices = {
            { "Whatever came up the stair today.", tag = 3, answer = "counter", when = { offer = "counter" } },
            { "Your own shelf.", tag = 4, answer = "shelf", when = { offer = "shelf" } },
            { "I am only passing.", tag = 5, answer = "leave" },
        } },
    },
}
