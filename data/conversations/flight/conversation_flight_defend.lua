-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- Played at the opening of the FIRST RESCUE FIGHT on floor one (encounter_survivors_defend, dealt off the
-- walk by states/prologue.lua's FLIGHT_QUEST `prowl` -- the entry's `opening`, carried onto the cell and
-- fielded by states/battle.lua). Board frozen behind it: delvers pinned down ahead of the party's line,
-- the demons already walking for them rather than for you, a wave due in from the tree line.
--
-- WHAT IT HAS TO CARRY, in two or three lines over a board the player can see:
--   * that these are PEOPLE, and the fight is won by keeping them standing -- the first fight in the game
--     whose objective is somebody else's life;
--   * nothing about the Shout. It is the SPOILS of this fight (it lands after the win), so naming it here
--     would be advice the player cannot take.
-- The avatar is silent through Act 0; Rowan speaks. Every line is the author's to write.
return {
    title = "Pinned Down",
    cast  = { "character_rowan", "character_avatar" },

    script = {
        { "character_rowan", "PLACEHOLDER -- there are delvers pinned down ahead, and the demons are going for them, not us.", tag = 1 },
        { "character_rowan", "PLACEHOLDER -- keep them standing; that is how this one is won.", tag = 2 },
    },
}
