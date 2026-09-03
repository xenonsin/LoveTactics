-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- KAYA, MET AT THE LODGE'S POSTING. The first beat of a recruit (models/errand.lua): she asks at the
-- doorway, the stag is the ask, and clearing it recruits her.
--
-- WHAT THIS SCENE HAS TO ESTABLISH: her name is "it is enough" and she has never taken past need
-- (data/characters/character_kaya.lua). The Lodge's posting wants antlers on a wall, which is a trophy,
-- which is the exact thing she is the answer to -- so she does not read the posting back, she RESTATES
-- it on her own terms and the terms are the character. Once, and nothing else. A companion whose first
-- scene agreed with the trophy would be temperance in name only.
--
-- The wolf is hers and is on the board from the first bell (trait_wolf_companion), so it is named here
-- rather than arriving unannounced in the fight.
return {
    title = "The White Stag",
    cast  = { "character_avatar", "character_kaya", { id = "character_rowan", when = { has = "character_rowan" } } },

    script = {
        { "character_kaya", "Down. Lower than that. The boars have your scent already and they will reach you a long time before the stag does.", tag = 1 },
        { "character_avatar", "{posting}", tag = 2 },
        { "character_kaya", "Antlers on a wall. That is what the Lodge wants and it is not why I have been sitting in this wood for nine days.", tag = 3 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "Nine days, and a wolf that has not left her side. She is not the one being hunted here, {name}.", tag = 4 },
        } },
        { "character_kaya", "It stopped being a stag two winters ago. It takes and it takes and the wood has gone quiet behind it -- so it comes down once, and nothing else in here does. Those are my terms and I do not move off them.", tag = 5 },
        { "character_kaya", "Agree to that and my wolf goes in first and I go after her. Agree to it and I will walk you out of this wood, and further than that if you are going.", tag = 6 },
        { "character_avatar", "We take it on her terms, or we leave the wood alone. Choose...", tag = 7, choices = {
            { "Take her terms.", tag = 8, answer = "accept" },
            { "Leave the wood.", tag = 9, answer = "decline" },
        } },
    },
}
