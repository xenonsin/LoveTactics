-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- THE BEAT AFTER THE FIRST WIN, played over the board's last frame with `deferJoins`.
--
-- IT USED TO SAY THE TRIP WAS FOR THE CLASS REQUIREMENTS, and opened the Roll (2026-10-16). Both are
-- gone (2026-10-23): Act 0 banks nothing toward a class, and the avatar's first class is Rowan's
-- recommendation to the guild, picked in the city (conversation_prologue_arrival). So this scene no
-- longer has to teach anything; what it carries now is the author's call -- or it can be cut, with its
-- beat in states/prologue.lua.
--
-- It took the slot of the Charter's roll, which named the avatar; naming moved back in front of the fight.
-- Every line is the author's to write.
return {
    title = "What We Came Down For",
    cast  = { "character_rowan", "character_avatar" },

    script = {
        { "character_rowan", "PLACEHOLDER -- the fight is won, and that is the first of what we came down here to do.", tag = 1 },
        { "character_rowan", "PLACEHOLDER -- why they came down: to make a name, which is what the guild ranks.", tag = 2 },
        { "character_rowan", "PLACEHOLDER -- and that floor one is where everybody's starts.", tag = 3 },
    },
}
