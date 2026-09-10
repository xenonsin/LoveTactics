-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- TWO LINES, AND THEY ARE NOT A SCENE. A hint bag like the first wound's: coach lines
-- (ui/coach_bubble.lua) pinned to the dead end a companion is standing at, drawn while the first
-- recruit in the game is still outstanding (states/game.lua's drawRecruitCoach).
--
-- WHY THE MAP OWES THIS ONE A BUBBLE AT ALL. A floor's ends are all the same marker on the same kind of
-- spur (models/errand.lua), and one of them is a person. The scene at the doorway introduces HER --
-- it does not say that a body met down here is how the company grows, that hearing her out is free, or
-- that the fight behind her is the price of keeping her. The player meets all of that once, on floor
-- one of the first descent (models/descent.lua's SCRIPTED_COMPANION), and never learns it from a
-- marker again.
--
-- TWO LINES BECAUSE A RECRUIT IS TWO BEATS and the bubble must not go stale between them. Before the
-- ask, the mark is an invitation and the walk is the whole cost; after it, the same mark is a fight
-- that has been agreed to. One line covering both would be lying on one side of the answer.
--
-- IT NAMES NO BUTTON. Nothing here asks for a press -- what it asks for is a walk, which every device
-- already does -- so neither line carries {select} and neither bubble draws a key cap.
return {
    title = "Somebody At The End Of It",
    cast  = { "character_rowan" },

    script = {
        { "character_rowan", "Somebody is standing at that end, with work of her own to ask for. Walking up to hear it costs us nothing. Doing the job she names is what brings her into the company.", tag = 1, id = "recruit_hint" },
        { "character_rowan", "She is waiting on the far side of that door, and the work she asked for is the way through it. Win that fight and she comes out with us.", tag = 2, id = "recruit_asked_hint" },
    },
}
