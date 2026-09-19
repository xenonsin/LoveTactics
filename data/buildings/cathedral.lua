-- THE CATHEDRAL: the priests' house, and where a bone gets set.
--
-- ITS SHELF is relics, rites and what the church will part with, deepening as the roster's priest level
-- climbs (Quest.shelfRung) rather than opening whole.
--
-- AND ITS SECOND ROOM IS THE INN, which is the one room in the city about the LAST expedition rather
-- than the next one. It stood on the plaza as a card of its own; it is a line on this desk now, and the
-- fold was already half-written in the data before anybody proposed it -- the Inn granted
-- `character_xin` on its first visit, and data/vendors/cathedral.lua names `character_xin` as this
-- house's companion. The same healer was standing in two rooms.
--
-- TWO WAYS OUT OF A WOUND, and the pair is the whole room (models/wound.lua's ward block):
--   * REST -- free, always, no gate and no purse test. The body lies up for Wound.REST_DESCENTS trips
--     per wound and is out of the company while it does, so the cost is paid in who walks down without
--     them. A stay is served by DESCENDING (models/gate.lua's Gate.night).
--   * TREAT -- Wound.TREAT_COST in gold, and the bone is set before you leave the room.
-- The gold buys SPEED and never recovery. That is not decoration: it is the reason this room is allowed
-- to exist at all, after two earlier versions of it were deleted for charging at the door.
-- docs/the-count.md states the law -- a cost on recovery is a tax on NEEDING to recover -- and a free
-- path that is always open is what keeps this on the right side of it. Read that before pricing either.
return {
    name = "The Cathedral",
    order = 3,
    x = 490,
    y = 120,
    w = 300,
    h = 130,
    vendor = "cathedral",
    -- The desk: what this house says on the way in, and the rooms it offers (models/counter.lua).
    counter = "conversation_cathedral_counter",
    offers = {
        -- QUIET: a class rung stocks this shelf but never puts the card on the plaza. A class level is
        -- a reward the player cannot see, and hanging a door on it put shopfronts in the city that
        -- nobody chose to earn (models/offer.lua's Offer.any).
        { answer = "shelf", panel = "shop", gate = { classLevel = 1 }, quiet = true },
        -- The line arrives the first time anybody is carried up broken, which is Rowan at the end of
        -- Act 0 (models/combat.lua's spendScriptedFell) -- so this door opens on the first morning with
        -- only its mending on the desk, and the shelf joins it when somebody has climbed a priest rung.
        -- A player meets this counter holding exactly the problem it solves.
        { answer = "mend", panel = "ward", gate = { wound = true } },
    },
    -- WHAT THIS ROOM SAYS THE FIRST TIME IT IS WALKED INTO, and who is standing in it. `grants` recruits
    -- as the scene opens so her join banner folds onto the end of it, exactly as every other companion's
    -- does (models/counter.lua). She is the only companion in the game met above ground.
    intro = "conversation_ward_first_visit",
    grants = "character_xin",
    description = "Relics and rites, and the only bed in the city that will set a bone.",
}
