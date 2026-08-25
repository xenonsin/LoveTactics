-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- WHAT THIS FOLDER IS. Seven scenes, one per circle, played over the stair guardian of a descent floor
-- (models/descent.lua's floorQuest -> the objective's `opening`, which states/game.lua hands to the
-- battle). The campaign's own confrontations live under each house's folder and are a different job
-- entirely: those are the end of a ten-quest line, they run to forty lines, and they are written for the
-- companions the player recruited along it.
--
-- A DESCENT HAS NONE OF THAT, and the scenes are shaped by what it does not have.
--
--   No avatar. A descent's company is one authored body plus whoever it found on the floors
--   (it was handed generic bodies). There is nobody here the general could recognise and nobody the
--   player has a history with, so every one of these is ONE SPEAKER and no reply. A `when = { has = }`
--   block would never fire; the cast is her alone.
--
--   No history. She has not been hunted down at the end of a line. Four strangers have walked onto her
--   floor on their way to a stair, which is what happens on her floor.
--
--   It plays EVERY RUN. Hades' bosses talk every time and that is the point of them; the cost of the
--   sound is length. Two or three lines, and they do not build to anything.
--
-- So what a general has to say here is not her story. It is one remark about the descent, in her own
-- idiom -- which for all seven is the same shape, because all seven bought a thing and were given its
-- cruel inverse. She is not surprised to see anybody. She has been down here a long time.

return {
    title = "Gula, the Unsated",
    cast  = { "character_general_gluttony" },

    script = {
        { "character_general_gluttony", "You are going further down. They all are.", tag = 1 },
        { "character_general_gluttony", "I ate the last four who came through saying it. I could not describe one of them to you now. There is nothing in me that keeps things.", tag = 2 },
    },
}
