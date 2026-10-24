-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- BARKS: a companion's one-line remark, drawn as a speech bubble over the party token and gone on its
-- own a few seconds later (states/game.lua's game:bark). A BAG, like the other files in this folder --
-- read line by line through Locale.node by id, never played as a scene, because a bark must not stop
-- the walk the way a scene does.
--
-- stair_down: Act 0's floor one, after the Champion. Its tile becomes the stair down and nobody takes it
-- -- Rowan is down and nothing like that should be this shallow (conversation_flight_turn_back) -- so
-- every step onto it gets this, and the way up at the door pulses gold (ui/overworld_map.lua). The
-- line is a PLACEHOLDER; the words are the author's.
return {
    title = "Barks",
    cast  = { "character_rowan" },

    script = {
        { "character_rowan", "PLACEHOLDER -- not down there, not today; the way up is back at the door.", tag = 1, id = "stair_down" },
    },
}
