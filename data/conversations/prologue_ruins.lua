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
-- for the one case that genuinely needs it: the battle opening, where the board underneath is being
-- read tile by tile (data/conversations/prologue_village.lua).
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
    cast  = { "character_avatar", "character_knight" },

    script = {
        { "character_avatar", "I can still see the smoke from here. That's not just our roofs, is it.", tag = 1 },
        { "character_knight", "No. Look past the fords -- every steading down the valley is burning, and the ones that aren't are already cold. They came through the whole of it in a night.", tag = 2 },
        { "character_avatar", "Then there are others. People who ran, like we ran.", tag = 3 },
        { "character_knight", "Almost certainly. Scattered, hiding, no idea which way is safe.", tag = 4 },
        { "character_avatar", "We find them. I'm not walking past someone who's still out there.", tag = 5 },
        { "character_knight", "Good. That is the right instinct, and I would have argued you into it if you hadn't got there first. We take who we find, and we keep moving while we do it.", tag = 6 },
        { "character_avatar", "Moving where? There's nothing left behind us.", tag = 7 },
        { "character_knight", "The capital. Its walls are the last ones standing between here and the sea, and they hold a great deal more than a village gate.", tag = 8 },
        { "character_avatar", "You don't sound certain.", tag = 9 },
        { "character_knight", "I am certain of the walls. I am less certain of the road -- the army that did this is walking it too, and it is not in a hurry. Stay close, {name}, and we will get there before they do.", tag = 10 },
    },
}
