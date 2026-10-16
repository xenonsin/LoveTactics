-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- WHY THE COMPANY IS ON FLOOR ONE AT ALL (2026-10-16), said the moment the first fight is won: the avatar
-- is a Novice, and a class is earned by deeds (data/class_requirements.lua). This trip is for meeting the
-- requirements. Played over the board's last frame with `deferJoins`, and the Roll opens with it
-- (states/prologue.lua's beat, Descent.markClassesOpen), so the overworld's first loadout lesson hands on
-- to the class tab.
--
-- It took the slot of the Charter's roll, which named the avatar; naming moved back in front of the fight.
-- Every line is the author's to write.
return {
    title = "What We Came Down For",
    cast  = { "character_rowan", "character_avatar" },

    script = {
        { "character_rowan", "PLACEHOLDER -- the fight is won, and that is the first of what we came down here to do.", tag = 1 },
        { "character_rowan", "PLACEHOLDER -- a class is earned down here: the requirements are deeds, and this trip is for meeting them.", tag = 2 },
        { "character_rowan", "PLACEHOLDER -- check where you stand on the Roll when we have a moment.", tag = 3 },
    },
}
