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
--   ward_card   states/hub.lua   -- the first morning's FIRST door (INTRO_STAGES). The company walks
--                                 out of Act 0 with Rowan hurt, so the city's opening instruction is
--                                 where that gets seen to -- and Xin is standing in the room.
--   rift_card   states/hub.lua   -- the first morning's second door (INTRO_STAGES), again. It was retired
--                                 for a pass when the Bounty Board held the plaza, and kept rather
--                                 than cut precisely because a translated line is dear to lose and
--                                 the door might come back. It did.
--   board_card  states/hub.lua   -- RETIRED with the board's card (the campaign is a distance run).
--                                 Kept on the same reasoning that kept rift_card: it is translated,
--                                 and models/bounty.lua is parked rather than deleted.
--   mend_row    ui/panels/ward.lua -- the Inn's ONE row, on the one morning somebody is standing in
--                                 front of it not knowing a wound is a thing you go and answer. The
--                                 only line in this bag pinned to a control INSIDE a panel rather
--                                 than to a card on the plaza; the bubble is the same widget.
--
--                                 IT NAMES THE PAID ROW, and the ring goes round that row alone. The
--                                 window one beat earlier taught BOTH ways out and did not rank them,
--                                 which is right -- the choice is the room. This instruction is not
--                                 the room, it is the first morning, and on the first morning the two
--                                 are not equal: resting benches Rowan for Wound.REST_DESCENTS trips
--                                 and the very next thing the city asks for is an expedition of four
--                                 (models/descent.lua's PARTY_MAX) out of a company of three. A coach
--                                 that shrugged here would be teaching the player to walk down a body
--                                 short on the one descent where they cannot yet know that costs
--                                 anything. The purse is 250 at this point and the bone is 40, so the
--                                 recommendation is one the player can always take.
--   mend_rest   ui/panels/ward.lua -- ...and the same bubble on the FREE row, for a purse that cannot
--                                 cover the other one. The campaign cannot reach it today (see above)
--                                 and it is authored anyway, because the alternative is a coached room
--                                 whose bubble points at nothing the day that figure moves -- and the
--                                 lesson would then be unfinishable, since the city holds the plaza
--                                 until somebody is seen to.
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
        { "character_rowan", "{select} the Inn. They will see to that arm, and it costs nothing to wait.", tag = 5, id = "ward_card" },
        { "character_rowan", "{select} the Rift. The stair down is inside.", tag = 2, id = "rift_card" },
        { "character_rowan", "{select} the Bounty Board. The houses post their work there.", tag = 4, id = "board_card" },
        { "character_rowan", "{select} {door}", tag = 3, id = "new_door" },
        { "character_rowan", "{select} to set {who}'s bone now. Resting mends it too, and costs the trips she is in bed for.", tag = 6, id = "mend_row" },
        { "character_rowan", "{select} to rest {who}. The purse will not cover setting the bone today.", tag = 7, id = "mend_rest" },
    },
}
