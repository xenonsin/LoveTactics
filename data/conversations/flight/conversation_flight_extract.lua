-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- Played at the opening of the SECOND RESCUE FIGHT on floor one (encounter_survivors_extract, dealt off
-- the walk by states/prologue.lua's FLIGHT_QUEST `prowl` -- the entry's `opening`, carried onto the cell
-- and fielded by states/battle.lua). Board frozen behind it: one survivor making for the far edge on
-- their own, demons closing the road, and every blow they throw BURNS -- cinders, brimstone.
--
-- WHAT IT HAS TO CARRY, in two or three lines:
--   * that the job is getting that one person OUT -- they walk on their own, so the party clears their
--     path rather than the board;
--   * that these demons burn -- the thing the Salamander Hide (this fight's spoils) answers, said as
--     something Rowan sees rather than as a hint about a coat the player does not have yet.
-- The avatar is silent through Act 0; Rowan speaks. Every line is the author's to write.
return {
    title = "The Way Out",
    cast  = { "character_rowan", "character_avatar" },

    script = {
        { "character_rowan", "PLACEHOLDER -- a survivor is making a run for the tree line, and the demons are closing the road.", tag = 1 },
        { "character_rowan", "PLACEHOLDER -- everything they throw is burning; clear the road ahead of them.", tag = 2 },
    },
}
