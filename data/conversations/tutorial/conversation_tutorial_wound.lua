-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- ONE LINE, AND IT IS NOT A SCENE. This is a coach line (ui/coach_bubble.lua), pinned to the wounded
-- member's row in the overworld party strip the first time anybody in the company is carried out of a
-- fight (states/game.lua's inflictWounds -> drawCoach). It lives in a conversation file rather than as
-- a string in the state for the same reason the flight leg's hints do: it goes through Locale, so it
-- translates like a spoken line and needs no wiring of its own.
--
-- IT NAMES NO DOOR, and it used to be careful not to for a reason that has since evaporated: a wound
-- was mended at the Inn, in the city, and an instruction pointing at a building the player is not
-- standing in is a thing to remember rather than a thing to do. There is no Inn now and no bill --
-- coming up the stair sets every bone (models/wound.lua) -- so the line has nothing to withhold. What
-- it owes the player is what a wound IS while they are still down here, which is all it ever said.
--
-- BOTH HALVES OF THE SCOPE, in one sentence, because the two are one decision. The band is held until
-- the company is above ground, so the rest of this expedition is being made by a company short of that
-- much -- and a Rest stop will bind it if the stop is spent on that instead of on healing, sharpening
-- or studying (states/game.lua's restBind). That is a push-on-or-turn-back input, and it is only worth
-- anything while there is still a board to walk.
--
-- Which is also why a wipe skips it entirely: a wiped company is standing in a town with every bone
-- already set, and a bubble teaching a mark that is no longer on any bar teaches nothing.
return {
    title = "Carried Out",
    cast  = { "character_rowan" },

    script = {
        { "character_rowan", "They were carried out of that fight. The dark band on their bar stays held back until we are above ground again - or until we spend a camp binding it instead of resting.", tag = 1, id = "wound_hint" },
    },
}
