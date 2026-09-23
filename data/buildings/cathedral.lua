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
-- TWO WAYS OUT OF AN INJURY, and the pair is the whole room (models/injury.lua's ward block):
--   * REST -- free, always, no gate and no purse test. The body lies up for Injury.REST_DESCENTS trips
--     per injury and is out of the company while it does, so the cost is paid in who walks down without
--     them. A stay is served by DESCENDING (models/gate.lua's Gate.night).
--   * TREAT -- Injury.TREAT_COST in gold, and the bone is set before you leave the room.
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
        -- THE SHELF IS NEVER GATED, because the shelf IS the house. Under the card era a shut shelf
        -- hid the whole shopfront, so the gate and the door were one fact; the fold put these doors on
        -- the plaza for OTHER rooms' sake, and the gate started meaning "walk through a shopfront and
        -- be offered no shop" -- which is what every desk in the city shipped reading.
        --
        -- A CLASS LEVEL BUYS DEPTH NOW and nothing else, which is the job Quest.shelfRung already
        -- describes itself doing: level 0 IS rung 0, the class's bottom band, and the ladder unlocks
        -- upward from there. Under the level-1 gate nobody could ever see rung 0 at all.
        --
        -- QUIET all the same: a shelf never puts a card on the plaza. A class rung is a reward the
        -- player cannot see, and hanging a door on it put shopfronts in the city that nobody chose to
        -- earn (models/offer.lua's Offer.any).
        { answer = "shelf", panel = "shop", quiet = true,
          -- ...except to the company training for it (models/offer.lua's `declared` gate).
          -- A shelf is not a deed the player can feel, so it stays quiet; taking up the class
          -- it sells IS one, and it is the only thing that puts this card on the plaza early.
          announce = { declared = true } },
        -- The line arrives the first time anybody is carried up broken, which is Rowan at the end of
        -- Act 0 (models/combat.lua's spendScriptedFell) -- so this door opens on the first morning with
        -- only its mending on the desk, and the shelf joins it when somebody has climbed a priest rung.
        -- A player meets this counter holding exactly the problem it solves.
        { answer = "mend", panel = "ward", gate = { injury = true } },
        -- ...AND THE RITE, which is the mending's twin with an item where the body goes
        -- (models/curse.lua). Same house, same two ways out, same law underneath: free and slow, or
        -- paid and now. It arrives the first time anything this company owns is hexed -- a trap in the
        -- rift, a caster, or the Touchstone naming a bad find -- so like the mending above, a player
        -- meets this room holding exactly the problem it solves.
        --
        -- NOT QUIET, and that is the difference between this and a shelf. A hexed piece is a thing the
        -- player can feel: a sword they cannot put down, a knight who will not walk. A door announcing
        -- itself on the plaza the morning after the first curse is the city answering a question the
        -- player has just been made to ask, which is the one event Offer.any exists to let through.
        { answer = "lift", panel = "rite", gate = { cursed = true } },
    },
    -- WHAT THIS HOUSE SAYS THE FIRST TIME IT IS WALKED INTO, and who is standing in it. `grants`
    -- recruits as the scene opens so her join banner folds onto the end of it, exactly as every other
    -- companion's does (models/counter.lua). She is the only companion in the game met above ground.
    intro = "conversation_ward_first_visit",
    grants = "character_xin",
    -- ...AND IT WAITS FOR THE BONE TO BE SET. `introAfter` names one of the answers above, and the
    -- scene plays as that room shuts instead of in the doorway (models/counter.lua).
    --
    -- It is the difference between a healer who is announced and one who does something. Played at the
    -- door, Xin introduced herself, said a bone could be set, and then the player went and set it off a
    -- menu while she stood there -- so the one companion in the game with a reason to come that is not
    -- a dice roll was introduced by a scene that happened BEFORE the reason. She mends Rowan now, and
    -- asks to come off the back of having done it. The coached morning holds the room open until that
    -- press lands (ui/panels/ward.lua's rail), so on the visit this fires the two are one moment.
    introAfter = "mend",
    description = "Relics and rites, and the only bed in the city that will set a bone.",
}
