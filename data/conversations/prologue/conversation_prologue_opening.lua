-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- THE FIRST THING A NEW GAME SAYS (2026-10-16), played over the prologue's plain backdrop before anything
-- else: Etrian Odyssey's opening narration. The old opening dropped the player onto a lane with no reason
-- to care; this is the reason. Three things, and only three: a city built around the rift, a city that
-- lives on what adventurers carry up out of it, and that you mean to make a name for yourself.
--
-- IT DOES NOT MENTION ROWAN OR XIN. The author's call: the narration is the city's and yours.
--
-- A NARRATOR, not a cast member: the speaker is no blueprint, so the cast entry names it (blank) and
-- carries no portrait. Every line is the author's to write.
return {
    title = "The Rift",
    cast  = { { id = "narrator", name = " " } },

    script = {
        { "narrator", "PLACEHOLDER -- a city built around a rift, a hole in the world that goes down and does not close.", tag = 1 },
        { "narrator", "PLACEHOLDER -- the whole city lives on what adventurers carry up out of it.", tag = 2 },
        { "narrator", "PLACEHOLDER -- and you have come to go down, and make a name for yourself.", tag = 3 },
    },
}
