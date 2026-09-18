-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- THE RIFT COPIES PLACES. That is the premise every companion meeting now stands on: the floors throw
-- up pieces of the world above, wrong and out of order, and each of the six is standing at one of them
-- because the thing she came for is in it. No house posted this, no counter sent anybody, and nobody
-- is met in the city. The meeting happens underground, on the floor, mid-run (models/errand.lua).
--
-- XIN, MET AT A MILL THE RIFT BUILT. She is the scripted first meeting of the whole game
-- (Descent.SCRIPTED_COMPANION), so this is the first companion scene most players will ever read and it
-- carries the premise for the other five: a mill, underground, with its wheel still turning.
--
-- WHAT IT HAS TO ESTABLISH, and it is her whole rule: she gives what is asked and refuses what is not
-- (data/characters/character_xin.lua). She bears no edge, keeps people standing, and ends nothing, so
-- the player has to ASK. That is the one thing that makes her different from every other body down here.
return {
    title = "The Miller's Ghost",
    cast  = { "character_avatar", "character_xin", { id = "character_rowan", when = { has = "character_rowan" } } },

    script = {
        { "character_xin", "You can lower that. I have been outside this mill since yesterday and it has not come out.", tag = 30 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "A mill. Under the ground, {name}. The rift has copied something it should not have.", tag = 31 },
        } },
        { "character_xin", "The man inside is still turning the wheel. He does not know the water is gone.", tag = 32 },
        { "character_xin", "I carry no blade and I cannot end him. Ask me in and I will keep all of you standing while you do.", tag = 33, choices = {
            { "Ask her in.", tag = 34, answer = "accept" },
            { "Leave the mill.", tag = 35, answer = "decline" },
        } },
    },
}
