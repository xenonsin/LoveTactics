-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- ============================================================================
-- THE SPOKEN LINES BELOW ARE PLACEHOLDERS. Structure settled, words are the author's.
-- ============================================================================
--
-- THE BLOW IS ALREADY ON HER. This plays in the middle of the Demon Champion's last stage, between
-- the strike landing and the body going down -- beat 5 of the six states/battle.lua walks through
-- (battle.SCRIPT_BEATS; the beat itself is described in data/status/status_champion_fixation.lua).
-- The board is frozen under it, the demon is standing where it hit her, and she is still on her feet
-- and still on the timeline, because her death cue is being HELD for exactly as long as this scene is
-- up. It is dismissed, and she drops.
--
-- SO IT IS NOT A DEATH SCENE, and writing one would be wrong twice over. She is FELLED, not killed
-- (models/combat.lua's Combat.fell): she is carried off the won board like any other casualty, the
-- fight's own ending is a fade rather than a defeat, and the very next room the player opens is the
-- Ward with her in it (data/conversations/ward/conversation_ward_first_visit.lua). A goodbye here
-- would be a promise the next ten minutes break.
--
-- WHY IT EXISTS AT ALL. The beat was reported by the author as "too sudden" -- and the sudden part was
-- never the felling, it was that nothing happened BETWEEN the demon arriving and the corpse. The walk
-- across the ground, the swing and the recoil are the board's half of that answer; this is the half
-- the board cannot give. One voice, one moment, with the hit already landed.
--
-- WHAT IT HAS TO DO, in a line or two and no more -- it is standing in the middle of a fight:
--   * COME FROM ROWAN. She has read this fight out loud for the player since the first street, and the
--     last thing she does in Act 0 is read the one thing she got wrong.
--   * BE SHORT. She has been hit hard enough to be taken off the board; a paragraph would say she
--     hasn't. Two lines is the ceiling and one may well be better.
--   * LEAVE THE FIGHT WINNABLE. The player is still holding a board with a Champion on it and is about
--     to be expected to finish the job. Nothing here may read as the run being over.
--
-- WHAT IT MUST NOT DO: ask for help, or name a way to save her. There isn't one -- the blow has landed
-- and the felling is unanswerable by design -- and a plea the game refuses is worse than silence. It
-- must not sound like a last word either, for the reason above.
--
-- The avatar is silent for the whole prologue as it stands, and there is no reason to break that here.
return {
    title = "She Does Not Get Up",
    cast  = { "character_rowan", "character_avatar" },

    script = {
        { "character_rowan", "PLACEHOLDER -- she says what she misread, with the blow already on her.", tag = 1 },
        { "character_rowan", "PLACEHOLDER -- and that the fight is still there to be finished.", tag = 2 },
    },
}
