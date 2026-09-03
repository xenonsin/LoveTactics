-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- REN, MET AT THE CRUCIBLE'S POSTING. The first beat of a recruit: she is standing at the doorway of the
-- chamber her work is in, she asks, and accepting only opens the way -- the fight inside is what brings
-- her into the company (models/errand.lua, and the quest's own `rewardCharacter`).
--
-- WHAT THIS SCENE HAS TO ESTABLISH, because it is the only place that ever will: the crate is a person.
-- The Crucible's posting says a reagent, and the objective's `allies` block says character_homunculus_
-- discard -- a made body that stands where it is put, does not fight, and whose death loses the job.
-- Ren is the alchemist who refuses to make them and shelters the ones the college calls spoiled batches
-- (data/characters/character_ren.lua), so she is the one person on this floor who says the word out
-- loud. Her kindness is the whole of her kit and it starts here.
--
-- Found by models/errand.lua's Errand.postingScene. `{house}` and `{posting}` are set for the scene's
-- duration (states/game.lua's askErrand); the avatar reads the posting so the job's own words still land
-- verbatim, and everything around it is hers.
return {
    title = "The Consignment",
    cast  = { "character_avatar", "character_ren", { id = "character_rowan", when = { has = "character_rowan" } } },

    script = {
        { "character_ren", "Stop there -- not for me, for the crate. Whatever the college told you is inside it, it is not a reagent, and it can hear every word we are saying.", tag = 1 },
        { "character_avatar", "{posting}", tag = 2 },
        { "character_ren", "Intact. They are always very specific about intact, and never once about alive. I have carried three of these off that road and I have never yet been given the word for what I was carrying.", tag = 3 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "She is unarmed, {name}, and she came down here anyway. That tells you what she thinks it is worth.", tag = 4 },
        } },
        { "character_ren", "The crew that took it will not hand it back to a woman with a satchel. Come in with me and it walks out. Do that, and I go where you go after -- I would rather spend myself on people who ask what is in the box.", tag = 5 },
        { "character_avatar", "We go in with her, or we leave it lying where it is. Choose...", tag = 6, choices = {
            { "Go in with her.", tag = 7, answer = "accept" },
            { "Leave it lying.", tag = 8, answer = "decline" },
        } },
    },
}
