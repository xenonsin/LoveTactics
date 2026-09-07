-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
-- This header survives a re-stamp: the tool reads the leading run of `--` lines back off disk and
-- re-emits it (tools/extract_strings.lua, `headerLines`). A comment further DOWN the file does not.
--
-- Played when the overworld map first appears (the flight leg's `opening` in states/prologue.lua).
-- Staged as an ORDINARY scene, like the beats either side of it; the compact `overScene` staging is
-- kept for a GUIDED fight's opening, where the board is being read tile by tile
-- (conversation_prologue_village.lua).
--
-- Three jobs:
--
--   * The SCALE. prologue_flee is one town wide. This is the valley, and what it widens to is that
--     BELLMERE'S WAS NOT THE ONLY FIELD THAT OPENED -- every column of smoke is another one. First
--     time the game says the rifts are a condition of the world rather than the player's bad night.
--     Rowan does NOT know why they open; she is reading smoke. The cause is Iselle's to sell, and a
--     knight who already had it would leave that scene with nothing.
--   * The MAP. The player's first one, arriving with no explanation -- markers, fog, a road. Naming
--     what they are FOR turns a screen of icons into an errand.
--   * The AVATAR'S VOICE. The errand -- go and find them -- is the avatar's line, not Rowan's. She
--     agrees with it rather than issuing it, which is the difference between a companion and a
--     quest-giver.
--
-- "Safe behind its walls" is dramatic irony and stays: the capital is sitting on the largest rift
-- there is, which is the sponsor scene's to reveal.
return {
    title = "The Road",
    cast  = { "character_avatar", "character_rowan" },

    script = {
        { "character_avatar", "Bellmere is gone. I don't know who else made it out.", tag = 6 },
        { "character_rowan", "Many did. We held that lane long enough.", tag = 2 },
        { "character_rowan", "Look down the valley, {name}. Ours wasn't the only field that opened last night.", tag = 3 },
        { "character_rowan", "Nobody stood in the road at those. Whoever ran is out in the hills.", tag = 7 },
        { "character_avatar", "Then let's find them.", tag = 4 },
        { "character_rowan", "The king's road to the capital, then. We'll be safe behind its walls, and we save who we can on the way.", tag = 5 },
    },
}
