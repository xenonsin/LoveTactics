-- THE CRUCIBLE: the alchemists' house, and where a find gets read.
--
-- ITS SHELF is draughts, coatings and jars labelled with something else's name, deepening as the
-- roster's alchemist level climbs (Quest.shelfRung) rather than opening whole.
--
-- AND ITS SECOND ROOM IS THE TOUCHSTONE (models/identify.lua). A crucible and a touchstone are the two
-- instruments of the same assay office -- one reads a streak of metal drawn across dark stone, the other
-- cupels it -- so the city's two names for reading an unknown thing were always one room. And the sin
-- lands it: greed wants the thing, envy wants the thing's PROPERTY, which is exactly what a reading
-- hands over.
--
-- NOT A SHOP, that one. It keeps no shelf and the panel it opens is a BENCH -- it takes a thing you
-- already own and changes it, the way the Forge does. Vendors sell; benches work. It keeps its own
-- keeper too (data/vendors/touchstone.lua), so `Identify.VENDOR` still reads "touchstone" and no save
-- has to be migrated for the stone to remember it has been visited.
--
-- THE READING ARRIVES ON THE FIRST THING NOBODY CAN READ, which is the most literal gate in the game:
-- the player finds the thing, cannot use it, and THEN the line is on the desk. Nothing has to explain it.
--
-- ...OR BY THE FIFTH TRIP, WHICHEVER COMES FIRST, and the backstop is not a hedge. An event gate that
-- may never fire is a room a player can be locked out of for a whole playthrough -- the drops decide,
-- and the drops do not know this door exists. The event is the moment worth having; the count is there
-- so nobody loses the room waiting for it.
return {
    name = "The Crucible",
    order = 8,
    x = 490,
    y = 480,
    w = 300,
    h = 130,
    vendor = "alchemist",
    -- The desk: what this house says on the way in, and the rooms it offers (models/counter.lua).
    counter = "conversation_alchemist_counter",
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
        { answer = "shelf", panel = "shop", quiet = true },
        -- Keeps its own vendor without keeping a shelf, exactly as the kitchen does: the portrait, the
        -- name, the one-time greeting -- and its record in `visitedVendors`, which is also what keeps
        -- the line standing once it has been used (models/identify.lua's Identify.everFound).
        -- The backstop moved 5 -> 6 when the Arcanum's study took the fifth trip: two rooms landing on
        -- one homecoming is the one thing the trip clock exists to prevent, and this is the half that
        -- is only a guarantee -- a company carrying a find it cannot read has the room already.
        { answer = "read", panel = "touchstone", vendor = "touchstone",
          gate = { any = { { unidentified = true }, { trips = 6 } } } },
    },
    description = "Draughts, coatings, and a stone that will say what a thing is.",
}
