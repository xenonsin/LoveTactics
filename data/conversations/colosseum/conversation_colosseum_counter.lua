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
return {
    title = "The Colosseum",
    cast  = { "colosseum" },

    script = {
        { "colosseum", "Sand, blood, and a crowd that does not care which of you it came from. What do you want off us.", tag = 1 },
        { "colosseum", "Well?", tag = 2, id = "desk", choices = {
            { "What wins fights.", tag = 3, answer = "shelf", when = { offer = "shelf" } },
            { "Put me against somebody.", tag = 4, answer = "duel", when = { offer = "duel" } },
            { "Nothing.", tag = 5, answer = "leave" },
        } },
    },
}
