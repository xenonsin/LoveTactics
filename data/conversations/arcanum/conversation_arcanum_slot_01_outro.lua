-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- ============================================================================
-- THE SPOKEN LINES BELOW ARE PLACEHOLDERS. Structure settled, words are the author's.
-- ============================================================================
--
-- PLAYED ON THE FLOOR, on the ground she could not take. GYEOM JOINS HERE: states/game.lua's errand
-- payout recruits `rewardCharacter` immediately before this plays, so the "[Gyeom has joined your
-- Party]" banner drains onto the end of it (models/conversation.lua). This is the fourth and last body
-- of the expedition arriving, so it is also the moment the company is finally whole.
--
-- REWRITTEN 2026-09-16 WITH ITS SCENE. What stood here was her over the recovered book -- "Do not open
-- it here. It has been under water a very long time" -- and the book is gone with the library premise.
-- See conversation_arcanum_errand_found.lua for the full record of what this house's line stopped
-- saying.
--
-- THE JOIN LINE IS THE POINT, AND IT IS ABOUT METHOD RATHER THAN STRENGTH. The old version's closing
-- line is the one thing worth carrying across intact in spirit: *"I would like to keep walking with
-- people who check their numbers before they open a door."* She does not join the strongest company she
-- could find; she joins the one that does the work properly.
--
-- AND IT POINTS AT WHAT SHE CAME FOR. She is down here to LEARN -- the workings that exist nowhere above
-- the rift -- and she has the grimoire now, which was one of them. The join is not gratitude for a
-- rescue and not a debt being settled: it is her doing the arithmetic out loud on what she just saw.
-- One book cost four bodies and a hard fight. There are more, they are further down, and she cannot
-- reach any of them alone. So she asks.
--
-- SHE FOUGHT IN IT, which changes the register of this scene from thanks to assessment. She was on the
-- board (the objective's `allies`), she saw how they work, and what she is really saying is that she
-- has measured this company the way she measures everything and would like to keep the result.
--
-- TWO LINES, NOT THREE OR MORE. Every beat after the join is spent, because the banner lands on the end
-- of this scene and the floor's stair is the next thing the player touches.
return {
    title = "What It Took",
    cast  = { "character_avatar", "character_gyeom" },

    script = {
        -- 1. SHE HAS THE BOOK, and says what it cost -- four bodies and that fight, for one working.
        --    A result, read off the fight she just stood in, not a thank-you.
        -- 2. THE JOIN: there are more of them, further down, and she cannot reach one alone. She asks.
        --    Method rather than gratitude -- she measured this company too. Banner folds onto this line.
        { "character_gyeom", "PLACEHOLDER -- she has the grimoire, and what taking it actually took.", tag = 1 },
        { "character_gyeom", "PLACEHOLDER -- there are more and they are deeper; she asks to come along.", tag = 2 },
    },
}
