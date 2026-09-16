-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- ============================================================================
-- THE SPOKEN LINES BELOW ARE PLACEHOLDERS. Structure settled, words are the author's.
-- ============================================================================
--
-- THE SECOND MEETING: an ask already agreed to and not yet run (models/errand.lua's `asked` kind) --
-- the player said yes, walked off, and has come back to her step without having taken the ground.
-- Short by design. It re-offers the same choice and nothing else.
--
-- REWRITTEN 2026-09-16 WITH ITS SCENE. What stood here was her correcting her count of the diggers in
-- the library -- "Twelve now. One of them came back with a friend" -- which was the right beat for the
-- character and the wrong premise entirely. See conversation_arcanum_errand_found.lua for what the
-- house's line stopped saying.
--
-- WHAT SHE IS WAITING BESIDE is the grimoire and the thing sitting on it, and she has been watching it
-- the whole time the player was away -- which is what gives her something new to report.
--
-- THE BEAT WORTH KEEPING FROM THE OLD VERSION, because it is the one thing she does that nobody else in
-- the roster does: she uses the second meeting to CORRECT HERSELF, out loud, unprompted. Something has
-- changed since she last gave the player a number and she says so and says why. That is the whole
-- character in two lines, and it is better placed here than anywhere else, because a player who walked
-- away and came back is the only one who gets to see her measure twice.
return {
    title = "The Thing on the Book",
    cast  = { "character_avatar", "character_gyeom" },

    script = {
        { "character_gyeom", "PLACEHOLDER -- what she told them before has changed, and she says why.", tag = 1 },
        { "character_gyeom", "PLACEHOLDER -- she will be here; the offer is still open.", tag = 2, choices = {
            { "Take it together.", tag = 3, answer = "accept" },
            { "Leave her to it.", tag = 4, answer = "decline" },
        } },
    },
}
