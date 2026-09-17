-- THE WARD: where a bone gets set, and the only door in the city that is about the last expedition
-- rather than the next one.
--
-- TWO WAYS OUT OF A WOUND, and the pair is the whole building (models/wound.lua's ward block):
--   * REST -- free, always, no gate and no purse test. The body lies up for Wound.REST_DESCENTS trips
--     per wound and is out of the company while it does, so the cost is paid in who walks down without
--     them. A stay is served by DESCENDING (models/gate.lua's Gate.night), which is the only thing in
--     this game that passes time.
--   * TREAT -- Wound.TREAT_COST in gold, and the bone is set before you leave the room.
-- So the gold buys SPEED and never recovery. That distinction is not decoration: it is the reason this
-- building is allowed to exist at all, after two earlier versions of it were deleted for charging at
-- the door. docs/the-count.md states the law it keeps -- a cost on recovery is a tax on NEEDING to
-- recover -- and a free path that is always open is what keeps this on the right side of it.
--
-- IT USED TO BE THE INN and the difference is not the name. The Inn took 60g a wound AT THE DOOR, or a
-- day a wound in a bed, and a wipe wounds the whole expedition by construction -- so a company that lost
-- badly woke poorer, worse, and holding a bill, with a roster too thin to rotate and no way to earn the
-- coin except to go back down hurt. It was deleted on 2026-09-02, building and all. What changed: the
-- rest is free, and the company now leaves Act 0 with three bodies and fills its fourth on floor one, so
-- there is finally somebody to bench INTO.
--
-- `unlockWound` -- the card arrives the first time anybody is carried up broken, which is Rowan at the
-- end of Act 0 (data/status/status_champion_fixation.lua). A player meets this door holding exactly the
-- problem it solves, which is the shape every late-arriving card on this plaza keeps.
--
-- AMANA IS HERE. She is met on the first visit and joins from it (models/vendor_visit.lua) -- the healer
-- introduced by the room where healing happens, rather than by a roll on a floor. She is the only
-- companion in the game recruited above ground.
return {
    name = "The Ward",
    order = 2,
    -- THE APPROACH -- the empty slot over the Gate, which models/building.lua's plaza map has been
    -- holding for the next card since the ring was laid out. This is that card, so it takes the
    -- middle column's width (300, the Gate's) rather than a ring card's 270: the column reads as a
    -- column. It was authored on (175, 120) -- the Houses' slot -- and the two plates drew on top of
    -- each other, the shut one's "???" printing over this one's name.
    x = 490,
    y = 120,
    w = 300,
    h = 130,
    panel = "ward",
    -- ONE SENTENCE, and it is the whole of what the player is told about this room before walking in
    -- (states/hub.lua's doorText, in a 240px bubble beside the card's name). It names both ways out,
    -- because a player who reads only "wounds are healed here" will assume it costs money and not open
    -- the door on the trip where they have none.
    description = "Rest a wound off for nothing, or pay to have it set today.",
    unlockWound = true,
    -- WHAT THIS ROOM SAYS THE FIRST TIME IT IS WALKED INTO, and who is standing in it. `grants` recruits
    -- as the scene opens so her join banner folds onto the end of it, exactly as every other companion's
    -- does (states/hub.lua's launchVendor). See the header: she is the only one met above ground.
    intro = "conversation_ward_first_visit",
    grants = "character_amana",
}
