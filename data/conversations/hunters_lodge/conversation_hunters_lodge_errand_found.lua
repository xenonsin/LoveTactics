-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- THE RIFT COPIES PLACES. That is the premise every companion meeting now stands on: the floors throw
-- up pieces of the world above, wrong and out of order, and each of the six is standing at one of them
-- because the thing she came for is in it. No house posted this, no counter sent anybody, and nobody
-- is met in the city. The meeting happens underground, on the floor, mid-run (models/errand.lua).
--
-- KAYA, MET AT A WOOD GROWING UNDER THE GROUND. What she came for is in it.
--
-- WHAT IT HAS TO ESTABLISH: her name is "it is enough" and she has never taken past need
-- (data/characters/character_kaya.lua). So the terms are the character, stated once and not moved off.
-- The wolf is hers and is on the board from the first bell (trait_wolf_companion), so it is named here
-- rather than arriving unannounced in the fight.
return {
    title = "The White Stag",
    cast  = { "character_avatar", "character_kaya", { id = "character_rowan", when = { has = "character_rowan" } } },

    script = {
        { "character_kaya", "Down. Lower than that. There is a wood on this floor and it has boars in it.", tag = 30 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "Trees, {name}. Under a mile of rock. Do not stand and stare at them.", tag = 31 },
        } },
        { "character_kaya", "The stag in it takes and takes, and the wood has gone quiet behind it.", tag = 32 },
        { "character_kaya", "So it comes down once, and nothing else in here does. Those are my terms.", tag = 33 },
        { "character_kaya", "Agree to them and my wolf goes in first. I go after her.", tag = 34, choices = {
            { "Take her terms.", tag = 35, answer = "accept" },
            { "Leave the wood.", tag = 36, answer = "decline" },
        } },
    },
}
