-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
-- NOTE FOR WHOEVER ADDS THE NEXT LINE HERE: `extract-strings` REWRITES this file when it stamps an
-- untagged line, and its serializer only knows about `title`, `cast` and `script` -- comments and any
-- other field are dropped on the way through. Author the line, run the tool, then put this header
-- back. Once every line carries a tag the tool leaves the file alone.
--
-- Played when the overworld map first appears (the flight leg's `opening` in states/prologue.lua,
-- fielded by states/game.lua). Staged as an ORDINARY scene -- full portraits, title, the usual dim --
-- exactly like prologue_intro and prologue_flee either side of it. It is a story beat that happens to
-- be triggered by a map rather than a beat about the map, and the compact `overScene` staging is kept
-- for the one case that genuinely needs it: a GUIDED fight's opening, where the board underneath is
-- being read tile by tile and the mentor is about to speak from the same gutter panel
-- (data/conversations/prologue_village.lua). Every other battle opening is staged like this one.
--
-- It has three jobs:
--
--   * The AFTERMATH. prologue_flee is a character beat -- Rowan's oath, sworn over her own dead
--     ground, and it belongs to the village. This is the wider shot: the valley, not the lane, and
--     the scale of what the Demon Lord's army actually did in a single night.
--   * The MAP. It is the first one the player has seen, and it arrives with no explanation --
--     markers, fog, a road. Naming what those are FOR (survivors to reach, a capital to reach before
--     the demons do) turns a screen of icons into an errand. Said one scene earlier, on the black
--     between beats, it would have been describing something not yet on screen.
--   * The AVATAR'S VOICE. This is the first time the player's own character speaks, and it is the
--     right place for it: the survivor of the burning village is the one person here with standing
--     to ask whether anyone else got out. Rowan carries the answers, but the errand -- go and find
--     them -- is the avatar's line, not hers. She agrees with it rather than issuing it, which is
--     the whole difference between a companion and a quest-giver.
return {
    title = "The Road",
    cast  = { "character_avatar", "character_rowan" },

    script = {
        { "character_avatar", "It's all gone. I don't know who made it out.", tag = 1 },
        { "character_rowan", "Many did. We held that gate long enough for them to run.", tag = 2 },
        { "character_rowan", "Look down the valley, {name}. Those villages burned too, with no one to hold a gate. Survivors will be hiding in the hills.", tag = 3 },
        { "character_avatar", "Then let's find them.", tag = 4 },
        { "character_rowan", "Good! We take the king's road to the capital, {name}. We'll be safe behind its walls, and we save anyone we can along the way.", tag = 5 },
    },
}
