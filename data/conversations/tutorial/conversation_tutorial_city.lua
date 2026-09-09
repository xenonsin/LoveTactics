-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- THE BUBBLES ABOVE GROUND: the two instructions the city and the Gate give, and the one they give
-- over and over. A hint bag like the flight leg's -- fetched by id (Locale.coach), never played in
-- order, never spoken by anybody. The windows' longer words are next door in
-- conversation_tutorial_notes.lua.
--
-- EVERY LINE OPENS WITH {select}, because every one of them is asking for a press. The token is what
-- keeps that device-honest: a key cap for pad and keyboard, "Click" for a mouse, "Tap" for a finger
-- (models/locale.lua's coachLine). A line here that wrote "Click" itself would be lying to two of the
-- three inputs this project supports, and tests/tutorial_spec.lua fails the build over it.
--
-- WHO FIELDS THEM:
--   gate_stair  states/gate.lua  -- the descend row, until the company has actually gone down
--   rift_card   states/hub.lua   -- the first morning's one door (INTRO_STAGES)
--   new_door    states/hub.lua   -- every door the city grows afterwards, one per morning
--
-- new_door CARRIES A {door} TOKEN rather than a sentence, and that is the whole of what this file can
-- honestly own: the room's name and what it is for belong to the building blueprint
-- (data/buildings/*.lua, composed by hub.lua's doorText), which is content this pipeline does not
-- reach yet. What is translatable here is the FRAME -- the press, and where the name sits in it.
return {
    title = "The City's Instructions",
    cast  = { "character_rowan" },

    script = {
        { "character_rowan", "{select} to take the stair down.", tag = 1, id = "gate_stair" },
        { "character_rowan", "{select} the Rift. The stair down is inside.", tag = 2, id = "rift_card" },
        { "character_rowan", "{select} {door}", tag = 3, id = "new_door" },
    },
}
