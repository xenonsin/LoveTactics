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
-- ...OR ON ITS TRIP IN THE CITY SCHEDULE (models/offer.lua's Offer.SCHEDULE -- trip 1), whichever comes
-- first, and the backstop is not a hedge. An event gate that
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
        -- THE SHELF OPENS ON THE CITY SCHEDULE (models/offer.lua's Offer.SCHEDULE): one house's shelf per
        -- trip home, in a fixed order, unless a body unlocks this house's class first -- that pulls
        -- the shelf into the next trip's slot. Once open it stays open, and it announces its house:
        -- the plaza grows by one shopfront a homecoming. A class level still buys DEPTH and nothing
        -- else (Quest.shelfRung): level 0 is rung 0, the bottom band.
        { answer = "shelf", panel = "shop", gate = { city = "alchemist.shelf" } },
        -- Keeps its own vendor without keeping a shelf, exactly as the kitchen does: the portrait, the
        -- name, the one-time greeting -- and its record in `visitedVendors`, which is also what keeps
        -- the line standing once it has been used (models/identify.lua's Identify.everFound).
        -- A find nobody can read is a PROBLEM IN HAND and takes the trip's feature slot ahead of the
        -- schedule; trip 1 is only the guarantee (models/offer.lua's Offer.SCHEDULE).
        { answer = "read", panel = "touchstone", vendor = "touchstone",
          gate = { city = "alchemist.read" } },
    },
    description = "Draughts, coatings, and a stone that will say what a thing is.",
}
