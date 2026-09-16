-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- ============================================================================
-- THE LINES BELOW ARE PLACEHOLDERS. They are here so the beat RUNS, not so it reads. Every one of
-- them is to be replaced before this ships -- see the brief underneath.
-- ============================================================================
--
-- WHERE THIS SITS. Last beat of Act 0, between the Champion falling and the hub opening
-- (states/prologue.lua's buildBeats). The company carries Rowan off the sweep and into the Cathedral;
-- Amana is who they find there, and she leaves with them. It is the game's third companion join and
-- the only one that happens above ground.
--
-- THE THREE JOBS THIS SCENE DOES, in the order they matter:
--
--   1. IT MAKES THE WOUND A PERSON. Rowan is felled by script at the Champion's last stage
--      (data/items/utility/utility_demon_sigil.lua's `fell` response) and the ledger records it
--      (states/game.lua's inflictWounds, carved out of the tutorial exemption for exactly this).
--      So the first wound in the game is one the player watched land on somebody they have fought
--      beside since the first scene -- not a bar that got shorter. The scene is what collects on that.
--
--   2. IT INTRODUCES AMANA, and gives her a reason to come that is not a dice roll. She used to be
--      met underground on floor one and recruited by clearing her posting; a healer who joins because
--      somebody in front of her is hurt is the same join with a motive. Her old scene pair
--      (conversation_cathedral_errand_found / _asked) is what this replaces, and its best line is
--      worth lifting almost whole: *"I carry no blade and I cannot end him. Ask me in and I will keep
--      all of you standing while you do."*
--
--   3. IT PUTS THE PARTY AT FOUR before the first descent. See the roster note in
--      states/prologue.lua -- the fourth is Gyeom, met on floor one.
--
-- WHAT IT MUST NOT SAY: that the Cathedral is where you buy healing. There is no healing counter and
-- there is not going to be one -- a wound lasts an expedition and reaching the city ends it, free
-- (models/wound.lua's Wound.clear, called from hub.enter). So the promise this scene is allowed to
-- make is "the city puts you back together", never "come here and pay to be mended". A scene that
-- points at a shop that does not exist is a bug report waiting to be filed.
--
-- The mechanics agree with the fiction here without a single special case, which is worth not
-- breaking: the wound is live from the Champion's last stage until the hub opens, and the hub opening
-- IS the healing. Rowan walks into the next screen whole.
--
-- WHOSE VOICE. Amana carries it -- it is her introduction and her house. Rowan is present and hurt;
-- whether she speaks at all is an authoring call, though "the wall that holds its post" being unable
-- to stand is the whole image, and she is characterized by minding that more than the injury. The
-- avatar is silent for the rest of the prologue and there is no reason for that to change here.
return {
    title = "The Cathedral",
    cast  = { "character_amana", "character_rowan", "character_avatar" },

    script = {
        { "character_amana", "PLACEHOLDER -- she takes Rowan's weight without being asked.", tag = 1 },
        { "character_amana", "PLACEHOLDER -- what the city does for the people who go into the rift.", tag = 2 },
        { "character_rowan", "PLACEHOLDER -- she minds being carried more than she minds the wound.", tag = 3 },
        { "character_amana", "PLACEHOLDER -- she asks to come, and says what she is for.", tag = 4 },
    },
}
