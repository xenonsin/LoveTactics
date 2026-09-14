-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- THE RIFT COPIES PLACES. That is the premise every companion meeting now stands on: the floors throw
-- up pieces of the world above, wrong and out of order, and each of the six is standing at one of them
-- because the thing she came for is in it. No house posted this, no counter sent anybody, and nobody
-- is met in the city. The meeting happens underground, on the floor, mid-run (models/errand.lua).
--
-- GYEOM, MET ON THE STEP OF A FLOODED READING ROOM the rift has put a long way below where it was built.
-- Other parties are already inside, digging for what is in it.
--
-- WHAT THIS SCENE HAS TO ESTABLISH: she is not a prodigy and does not pretend to be one. Gyeom is the
-- answer to Pride, the mage who showed no gift and did the work anyway (data/characters/
-- character_gyeom.lua), so she has already counted the room, already worked out she cannot take it, and
-- says so as a measurement rather than as modesty. Her kit reads weak on purpose and peaks late.
return {
    title = "The Reading Room",
    cast  = { "character_avatar", "character_gyeom", { id = "character_rowan", when = { has = "character_rowan" } } },

    script = {
        { "character_gyeom", "Please do not go through that door yet. There are eleven of them in there. I counted twice, from two positions.", tag = 30 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "The rift has copied a library, {name}, and flooded it on the way down.", tag = 31 },
        } },
        { "character_gyeom", "I have been on this step four hours working out how to take that room alone. I cannot.", tag = 32 },
        { "character_gyeom", "That is the arithmetic, not modesty. I did it properly and it comes out the same every time.", tag = 33 },
        { "character_gyeom", "With your company in it the arithmetic works. I would like the book.", tag = 34, choices = {
            { "Take the room.", tag = 35, answer = "accept" },
            { "Leave the book.", tag = 36, answer = "decline" },
        } },
    },
}
