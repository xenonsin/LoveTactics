-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- THE FIRST TIME THE COMPANY COMES BACK UP EARLY. Played at the Rift the moment they step off the stair
-- (states/gate.lua, gated on Descent.tallyTaught), with the tally already drawn beside her so she has
-- something to point at.
--
-- SHE IS NOT INTRODUCING THE PREMISE AND THIS IS NOT A REVELATION. Iselle said all of it on the road in
-- the first conversation of the game: nothing down there is born, it forms, the Crown pays by the floor
-- to keep the number down, and when the deep floors go unpruned it comes up the stair and out into the
-- country. That is what happened at Bellmere, which is the fight the player has already fought.
--
-- What this scene does is tell them that the thing she described is now A NUMBER WITH THEIR NAME ON IT.
-- So it explains the two directions and nothing else: deeper takes it down, coming up puts it up. Ten
-- lines, because the mechanic is one sentence and the rest is her saying what it costs.
--
-- THE REGISTER IS HERS FROM THE PROLOGUE: flat, transactional, short declaratives, no turns of phrase
-- and no warnings dressed up as threats. She is quoting her own ledger at somebody who works for her.
-- The closer is deliberately the same shape as the one she ends the road scene with ("be sensible about
-- how deep you go on the first day"), because a second piece of advice from the same person should
-- sound like the first one.
--
-- ROWAN IS GUARDED and the avatar is not, which is the one difference from the prologue scene. There the
-- header argues she is sworn and standing by construction, and at that moment she is. This fires an
-- unknown number of floors later, against a roster the player has been adding to and choosing from, so
-- the cheap guard is worth having. The avatar cannot be absent.
return {
    title = "The Tally",
    cast  = { { id = "sponsor", name = "Iselle" }, "character_avatar", { id = "character_rowan", when = { has = "character_rowan" } } },

    script = {
        { "sponsor", "You came up.", tag = 1 },
        { "sponsor", "That is allowed. It is paid for. Look at the tally beside the stair before you do it again.", tag = 2 },
        { "character_avatar", "What is it counting?", tag = 3 },
        { "sponsor", "What is down there. I told you it forms, and I told you what we call keeping the number down.", tag = 4 },
        { "sponsor", "You pruned the floors you walked. The one you turned your back on starts filling again tonight.", tag = 5 },
        { "sponsor", "Go deeper and the tally comes down. Come up and it climbs. There is nothing else in it.", tag = 6 },
        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "And when it fills.", tag = 7 },
        } },
        { "sponsor", "Then it does not wait for anybody to go down. It comes up this stair and out into the streets.", tag = 8 },
        { "sponsor", "You watched that happen at Bellmere. This city is larger and the stair is in the middle of it.", tag = 9 },
        { "sponsor", "Be sensible about how often you come up.", tag = 10 },
    },
}
