-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- TWO LINES, AND NEITHER IS A SCENE. Both are coach lines (ui/coach_bubble.lua), pinned to the injured
-- member's row in the overworld party strip and fired once ever each (states/game.lua's
-- inflictInjuries -> drawCoach). They live in a conversation file rather than as strings in the state
-- for the same reason the flight leg's hints do: they go through Locale, so they translate like spoken
-- lines and need no wiring of their own.
--
-- WHY TWO. An injury is one of seven kinds now (models/injury.lua) and they are not read in the same
-- place:
--
--   the band    Blood Loss takes a share of the health pool and draws the dark cap on the bar. That is
--               what the FIRST line teaches, and the prologue guarantees it goes first -- Rowan's
--               scripted fall deals Blood Loss by name, so the bubble always has a band to point at.
--   the badge   the other six stamp a status the body fights under, which does not draw on the strip at
--               all -- it is on the body card and on the timeline at the bell. The SECOND line fires
--               the first time one of those lands, and names where to look.
--
-- Folding them into one longer bubble was the alternative and it teaches half of itself against a
-- screen that cannot show it: on the day of the first injury there is no badge anywhere to find.
--
-- THE FIRST LINE WAS STALE FOR MONTHS, and it is worth recording what it said, because it was not
-- merely out of date -- it was teaching the player the opposite of the rule. It read: *"The dark band
-- on their bar stays held back until we are above ground again - or until we spend a camp binding it
-- instead of resting."* Reaching the surface used to set every bone for free (Injury.clear in
-- hub.enter). It has not since the Ward was built: mending is still free, but it is a thing you go and
-- DO, in a room, and a company that walks up the stair walks up still hurt. A player who believed this
-- line would dive on, expecting the stair to fix it.
--
-- So the line names the two things that actually end one -- the camp's bind, and the Ward -- and does
-- not promise the walk home. It still says both halves of the SCOPE in one sentence, because the two
-- are one decision: the rest of this expedition is being made by a company short of that much, and a
-- Rest stop will bind it if the stop is spent on that instead of on healing, sharpening or studying
-- (states/game.lua's restBind). That is a push-on-or-turn-back input, and it is only worth anything
-- while there is still a board to walk.
--
-- Which is also why a wipe skips them entirely: a wiped company is standing in a town, and a bubble
-- pinned to an overworld that is already gone draws nothing.
return {
    title = "Carried Out",
    cast  = { "character_rowan" },

    script = {
        { "character_rowan", "They were carried out of that fight. The dark band on their bar is health that will not come back - not from a potion, not from the stair. A camp can bind it instead of resting, or the Ward will set it when we are home.", tag = 1, id = "injury_hint" },
        { "character_rowan", "That one did not take blood, it took something else. It is on them until the Ward sees to it, and they will carry it into every fight - hold the pointer over them to read what it costs.", tag = 2, id = "badge_hint" },
    },
}
