-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- ONE LINE, AND IT IS NOT A SCENE. This is a coach line (ui/coach_bubble.lua), pinned to the wounded
-- member's row in the overworld party strip the first time anybody in the company is carried out of a
-- fight (states/game.lua's inflictWounds -> drawCoach). It lives in a conversation file rather than as
-- a string in the state for the same reason the flight leg's hints do: it goes through Locale, so it
-- translates like a spoken line and needs no wiring of its own.
--
-- WHAT IT DELIBERATELY DOES NOT SAY IS "GO TO THE INN". A wound cannot be mended out here, so an
-- instruction naming a door the player is not standing at is a thing to remember rather than a thing
-- to do -- and the city already teaches that door the moment it grows it (states/hub.lua's
-- coachNextDoor, off data/buildings/the_inn.lua's own description). What this line owes the player is
-- the half the city cannot tell them, because by then the run is over: the mark on the bar, and that
-- the rest of this expedition is being made by a company that is short of that much. That is a
-- push-on-or-turn-back input, and it is only worth anything while there is still a board to walk.
--
-- Which is also why a wipe skips it entirely: a wiped company is standing in the city, and the Inn's
-- own card is the better teacher of a lesson whose answer is a door.
return {
    title = "Carried Out",
    cast  = { "character_rowan" },

    script = {
        { "character_rowan", "They were carried out of that fight. The dark band on their health bar is held back now - nothing out here will fill it again.", tag = 1, id = "wound_hint" },
    },
}
