-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- ROWAN'S WOUND, played over the city the moment the avatar's first class is picked and its panel
-- shuts (states/hub.lua's afterFirstPick). It is the hinge of the first morning: the guild's business
-- is done, and the next thing the company does is carry her to the Cathedral.
--
-- IT WAS THE TAIL OF THE ARRIVAL (conversation_prologue_arrival) until 2026-11-02, and it moved because
-- the class pick sat between her saying it and the bubble that acts on it. She asked for a priest, the
-- player spent a whole screen choosing a class, and the Cathedral bubble went up on a request nobody
-- remembered being made. Said here, the rail that follows (every plaza card but the Cathedral refuses
-- until she is mended, and its desk offers only the mending -- models/counter.lua) is answering the line
-- the player has just read.
--
-- WHAT COMES AFTER IT: the player is pointed at the Cathedral, chooses the mending off its desk, and the
-- press that sets the bone hands to Xin's scene (conversation_ward_first_visit), which is where she
-- joins. So this scene must not name Xin -- she is met in the room, not announced before it.
--
-- Name the CATHEDRAL (the card's `name`), not "the Ward" -- that is the room behind its desk. The lines
-- are PLACEHOLDERS; the words are the author's.
return {
    title = "Rowan's Wound",
    cast  = { "character_rowan", "character_avatar" },

    script = {
        { "character_rowan", "PLACEHOLDER -- she says the Champion's blow is still on her, and she is hurt.", tag = 1 },
        { "character_rowan", "PLACEHOLDER -- and that she needs a priest at the Cathedral before anything else.", tag = 2 },
    },
}
