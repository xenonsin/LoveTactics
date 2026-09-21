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
-- THIS HOUSE'S OTHER ROOMS WERE NEVER PLAZA CARDS -- the bestiary came off the Rift screen, and the
-- study is the half of the forge's ladder a smith was never the right hand for (data/buildings/arcanum.lua
-- argues both). Pride's house is where a thing is named and where what you already carry is read deeper.
return {
    title = "The Arcanum",
    cast  = { "arcanum" },

    script = {
        { "arcanum", "This library has outlived every scholar who swore he could read it safely. Do not touch the shelves you were not sent to.", tag = 1 },
        { "arcanum", "Name what you came for.", tag = 2, id = "desk", choices = {
            { "Visit mage class trainer", tag = 3, answer = "shelf", when = { offer = "shelf" } },
            { "Go to the study", tag = 6, answer = "study", when = { offer = "study" } },
            { "Open the bestiary", tag = 4, answer = "bestiary", when = { offer = "bestiary" } },
            { "Leave", tag = 5, answer = "leave" },
        } },
    },
}
