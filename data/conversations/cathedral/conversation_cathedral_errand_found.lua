-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- AMANA, MET AT THE CATHEDRAL'S POSTING. The first beat of a recruit (models/errand.lua): she asks at
-- the doorway, the mill is the ask, and clearing it recruits her.
--
-- WHAT THIS SCENE HAS TO ESTABLISH, and it is her whole rule: she gives what is offered and refuses what
-- is not (data/characters/character_amana.lua). So she does not push, she does not bargain, and she says
-- outright what she cannot do -- she bears no edge, keeps people standing, and ends nothing. The player
-- has to ASK, which is the one thing that makes her different from every other body down here.
--
-- She is also the Cathedral's own, raised on its acolyte track and turned on it as a witness, so the
-- house's wording is something she holds at arm's length rather than repeats.
return {
    title = "The Miller's Ghost",
    cast  = { "character_avatar", "character_amana", { id = "character_rowan", when = { has = "character_rowan" } } },

    script = {
        { "character_amana", "You can lower that. Whatever is in the mill will not be talked out of it -- but it does not have to be met with drawn steel from the doorway either, and I would rather it was not.", tag = 1 },
        { "character_avatar", "{posting}", tag = 2 },
        { "character_amana", "Laid to rest. That is the Cathedral's phrase and it means made quiet. I was raised on that phrase. I have stopped pretending the two are the same sentence.", tag = 3 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "She wears their cloth and speaks of them like weather. Mark that, {name}.", tag = 4 },
        } },
        { "character_amana", "I carry no blade and I am not going to start. I can keep every one of you standing in that room and I cannot end what is in it -- that part is yours. Ask me, and you have everything I have. I will not take the work off you unasked.", tag = 5 },
        { "character_avatar", "We ask her in, or we leave the mill to the dark. Choose...", tag = 6, choices = {
            { "Ask her in.", tag = 7, answer = "accept" },
            { "Leave the mill.", tag = 8, answer = "decline" },
        } },
    },
}
