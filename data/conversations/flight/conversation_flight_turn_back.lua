-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- THE TRIP ENDS BY TURNING BACK (2026-10-16), played over floor one the moment the board comes back after
-- the Champion (states/prologue.lua's objective `opensExit.scene`, states/game.lua's openExitRoad). The stair
-- down is open on the tile it held and nobody takes it: Rowan is hurt, and the author's note is that she
-- says they are not strong enough to go further. The way out is the door the company came in by.
-- Every line is the author's to write.
return {
    title = "Not This Time",
    cast  = { "character_rowan", "character_avatar" },

    script = {
        { "character_rowan", "PLACEHOLDER -- that is the stair down, and we are not going down it.", tag = 1 },
        { "character_rowan", "PLACEHOLDER -- we are not strong enough to go further. Not yet.", tag = 2 },
        { "character_rowan", "PLACEHOLDER -- back the way we came, and up.", tag = 3 },
    },
}
