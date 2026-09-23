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
-- XIN IS BEHIND THIS DOOR, and the room she is in is the mending -- so on the first morning of a fresh
-- save this counter opens with exactly one room on the desk and the shelf still shut. That is the
-- arrival the first morning is about, and the city outside it says nothing -- the plaza coaches
-- nothing at all (states/hub.lua's header), so this desk is where the lesson is.
return {
    title = "The Cathedral",
    cast  = { "cathedral" },

    script = {
        { "cathedral", "Cold in here. It is always cold in here. The faithful arm those who purge, and we keep beds for the ones who come back needing them.", tag = 1 },
        { "cathedral", "State your business.", tag = 2, id = "desk", choices = {
            { "Visit priest class trainer", tag = 3, answer = "shelf", when = { offer = "shelf" } },
            { "Heal an injury", tag = 4, answer = "mend", when = { offer = "mend" } },
            { "Lift a curse", tag = 6, answer = "lift", when = { offer = "lift" } },
            { "Leave", tag = 5, answer = "leave" },
        } },
    },
}
