-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- SABER, MET AT A DEAD END SOMEWHERE IN THE RIFT. The first beat of a recruit (models/errand.lua): she
-- is standing at an end the floor already carved, she asks for one piece of work, and clearing it
-- recruits her. Hers is the odd one of the six: every other companion asks you to go and fight
-- something else, and the thing behind Saber's ask is Saber (quest_colosseum_slot_01's objective).
--
-- SHE IS ROLLED LIKE THE REST, so depth is hers to talk about. The scripted floor-one meeting is
-- Amana's now (Descent.SCRIPTED_COMPANION), which is what lets Saber turn up deep and be surprised to
-- see anybody down there with her.
--
-- THE VIBE IS THE AUTHOR'S, from a two-line sketch: bored, cocky, delighted to see a party rather than
-- more rift raff, asking them to entertain her. Everything else was cut to keep those two beats clean.
-- No house, no card, no crowd, no gate. She walked in herself because she loves fighting and this is
-- where the hard ones are.
--
-- THERE IS NO WAY TO REFUSE HER, and that is authored rather than an oversight. Every other posting
-- ends on a two-option node -- take the work or leave it -- and hers ends on one answer, because a
-- fighter who has already decided you are her entertainment is not offering a choice. The machinery
-- is unchanged: the single choice still carries `answer = "accept"`, which is the only answer
-- states/game.lua acts on (askErrand / askErrandAtDoor). What is gone is the decline branch, so
-- stepping onto her end is committing to the bout.
--
-- SHE NEVER OFFERS TO JOIN. She is the only one of the six who does not need the company: what stands
-- at the dead end is a fighter who wants a challenge, and nothing in her head is recruiting anybody.
-- The recruit happens anyway, because the ask IS her bout and clearing it pays `rewardCharacter`.
--
-- SHE ALSO NO LONGER NAMES THE NETTER the objective fields beside her (character_trapper). Nothing
-- warns about it now: it is a surprise at the bell, and the deploy screen is the only thing that says
-- it is coming.
return {
    title = "Somebody Worth Swinging At",
    cast  = { "character_avatar", "character_saber", { id = "character_rowan", when = { has = "character_rowan" } } },

    script = {
        { "character_saber", "Hold there! Not used to seeing a party this deep. It is mostly rift raff down here.", tag = 21 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "She is alone and she is not worried, {name}. Keep your guard up.", tag = 22 },
        } },
        { "character_saber", "No house sent me and nobody is paying me. I came in looking for a fight worth having.", tag = 23 },
        { "character_saber", "I was growing bored. Care to be my entertainment?", tag = 24, choices = {
            { "Draw.", tag = 25, answer = "accept" },
        } },
    },
}
