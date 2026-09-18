-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- ============================================================================
-- THE SPOKEN LINES BELOW ARE PLACEHOLDERS. Structure settled, words are the author's.
-- ============================================================================
--
-- THE WARNING, PLAYED OVER THE BOARD, ONE TURN BEFORE IT HAPPENS. The Demon Champion crosses 33% health,
-- the stage turns, and it marks Rowan (models/combat.lua's Combat.spendScriptedFell). This plays at the next
-- turn boundary (states/battle.lua's beginTurn reads combat.pendingScene), and on the turn after it the
-- Champion shakes, crosses the ground and puts her down.
--
-- SO THE PLAYER IS TOLD TWICE AND STILL CANNOT STOP IT, which is the trade this beat makes and the
-- reason it is allowed to be unanswerable at all. Everything else unavoidable in this game is
-- telegraphed -- a wind-up, an intent preview, reinforcements committing their tiles two turns out -- so
-- a scripted moment that arrives with no tell reads as the player's own misplay, and they will replay
-- the fight trying to save her. The tell is this line, and then the shake on the body itself.
--
-- WHAT IT HAS TO DO, in one or two lines and no more:
--   * Say the thing has STOPPED FIGHTING THE FIGHT. Not that it is stronger -- that is what the
--     enrage already says in the log and on the badge. It has gone from swinging at whoever is in front
--     of it to having picked somebody, and that is a different kind of danger.
--   * Come from ROWAN, and be about the demon rather than about herself. She is the one who reads a
--     fight out loud for the player -- that is her whole function in Act 0 -- and the dramatic irony is
--     that the body explaining the danger is the one it has chosen. She must not notice that. A Rowan
--     who says "it is looking at me" turns the beat into her death scene a turn early, and the player
--     spends that turn trying to move her, which is the one thing they cannot be allowed to succeed at.
--
-- WHAT IT MUST NOT DO: name a counter, or suggest one. There isn't one. A line that says "get clear"
-- or "guard her" is an instruction the game will refuse, and a refused instruction from the mentor is
-- worse than no instruction at all.
--
-- The avatar is silent for the whole prologue as it stands, and there is no reason to break that here.
return {
    title = "It Has Stopped Fighting",
    cast  = { "character_rowan", "character_avatar" },

    script = {
        { "character_rowan", "PLACEHOLDER -- it has stopped swinging at whoever is nearest.", tag = 1 },
        { "character_rowan", "PLACEHOLDER -- it has picked somebody. She does not know it is her.", tag = 2 },
    },
}
