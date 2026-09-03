-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- GYEOM, MET AT THE ARCANUM'S POSTING. The first beat of a recruit (models/errand.lua): she asks at the
-- doorway, the fight inside is the ask, and clearing it is what recruits her.
--
-- WHAT THIS SCENE HAS TO ESTABLISH: she is not a prodigy and does not pretend to be one. Gyeom is the
-- answer to Pride -- the mage who showed no gift and did the work anyway (data/characters/
-- character_gyeom.lua) -- so she meets the party having already counted the room, already worked out she
-- cannot take it, and she says so as a measurement rather than as modesty. Her kit reads weak on purpose
-- and peaks late; her opening line should read the same way.
return {
    title = "The Reading Room",
    cast  = { "character_avatar", "character_gyeom", { id = "character_rowan", when = { has = "character_rowan" } } },

    script = {
        { "character_gyeom", "Please do not go through that door yet. There are eleven of them in the reading room. I have counted them twice, from two positions, because once is not counting.", tag = 1 },
        { "character_avatar", "{posting}", tag = 2 },
        { "character_gyeom", "I have been sitting on this step for four hours working out how to take that room alone. The honest answer is that I cannot. That is not modesty, it is the arithmetic -- I did it properly and it comes out the same each time.", tag = 3 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "Four hours on a step, and she did not go in. There are worse things to have in front of you, {name}.", tag = 4 },
        } },
        { "character_gyeom", "With your company in it, the arithmetic works. I would like the book. Rather more than the book, I would like to keep walking with people who check their numbers before they open a door.", tag = 5 },
        { "character_avatar", "We take the room, or we leave the book to the diggers. Choose...", tag = 6, choices = {
            { "Take the room.", tag = 7, answer = "accept" },
            { "Leave the book.", tag = 8, answer = "decline" },
        } },
    },
}
