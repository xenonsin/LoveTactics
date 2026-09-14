-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- THE RIFT COPIES PLACES. That is the premise every companion meeting now stands on: the floors throw
-- up pieces of the world above, wrong and out of order, and each of the six is standing at one of them
-- because the thing she came for is in it. No house posted this, no counter sent anybody, and nobody
-- is met in the city. The meeting happens underground, on the floor, mid-run (models/errand.lua).
--
-- REN, MET AT A PIECE OF THE CRUCIBLE'S ROAD. The rift has laid down a stretch of it with a consignment
-- still standing on the verge and a crew around the crate.
--
-- WHAT THIS SCENE HAS TO ESTABLISH, because it is the only place that ever will: the crate is a person.
-- The objective's `allies` block is character_homunculus_discard, a made body that stands where it is
-- put, does not fight, and whose death loses the job. Ren is the alchemist who refuses to make them and
-- shelters the ones the college calls spoiled batches (data/characters/character_ren.lua), so she is the
-- one person on this floor who says the word out loud. Her kindness is the whole of her kit.
return {
    title = "The Consignment",
    cast  = { "character_avatar", "character_ren", { id = "character_rowan", when = { has = "character_rowan" } } },

    script = {
        { "character_ren", "Stop there. Not for me. For the crate.", tag = 30 },
        { "character_ren", "That is a stretch of the Crucible's road, down here, with a consignment still standing on it.", tag = 31 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "She is unarmed, {name}, and she came down here anyway.", tag = 32 },
        } },
        { "character_ren", "What is inside it is not a reagent. It can hear every word we are saying.", tag = 33 },
        { "character_ren", "That crew will not hand it back to a woman with a satchel. Come in with me and it walks out.", tag = 34, choices = {
            { "Go in with her.", tag = 35, answer = "accept" },
            { "Leave it lying.", tag = 36, answer = "decline" },
        } },
    },
}
