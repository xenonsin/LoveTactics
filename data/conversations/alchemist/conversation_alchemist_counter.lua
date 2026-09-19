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
-- THE READING IS THIS HOUSE'S SECOND ROOM (models/identify.lua). A crucible and a touchstone are the two
-- instruments of one assay office, and the keeper behind the reading is still the stone's own
-- (data/vendors/touchstone.lua) -- so that line opens a room with a different face in it.
return {
    title = "The Crucible",
    cast  = { "alchemist" },

    script = {
        { "alchemist", "Mind the jars. Half of them are labelled with something else's name, and the labels are not the mistake.", tag = 1 },
        { "alchemist", "What do you want of us?", tag = 2, id = "desk", choices = {
            { "Draughts and coatings.", tag = 3, answer = "shelf", when = { offer = "shelf" } },
            { "I am carrying something nobody can name.", tag = 4, answer = "read", when = { offer = "read" } },
            { "Nothing.", tag = 5, answer = "leave" },
        } },
    },
}
