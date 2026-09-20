-- THE UNDERCROFT: the rogues' house, the fence, and the town's own counter.
--
-- ITS SHELF is everything that belonged to somebody else, deepening as the roster's rogue level climbs
-- (Quest.shelfRung) rather than opening whole. Its SERVICE is the Fence, the one thing only this house
-- does (models/vendor.lua's Services block): hand over a piece, name what you want back, same worth, a
-- fee for the trouble.
--
-- AND ITS SECOND ROOM IS THE MARKET. Read the two descriptions next to each other and they are the same
-- counter written twice -- "everything anyone came back up with, and a few things nobody did" against
-- "everything here belonged to someone else". Greed's house, and the swap is greed's verb: nothing is
-- created, nothing is destroyed, and somebody takes a cut of the difference.
--
-- IT IS A SECOND ROOM AND NOT THIS SHELF, which is the part worth being careful about. `sellsAll` makes
-- a Buy tab the market's two racks INSTEAD of a class ladder (ui/panels/shop.lua's buildMarketRows), so
-- pouring the counter into this vendor would have quietly deleted the rogue shelf rather than merged
-- with it. The market keeps its own vendor blueprint and its own panel; what it lost was its card.
--
-- THE COUNTER IS THE FIRST DOOR THE CITY GROWS, on the first trip home. The first morning
-- has exactly ONE thing to teach and it is the stair -- doubly so when almost nothing is on the shelf
-- yet, since a counter stocks a ware only once the company has carried one out (models/vendor.lua's
-- `lockReason`). So the city opens on the Armory and the Rift, the player goes down, and this door is
-- standing there on the way back up at the exact moment there is loot to sell and gold to spend.
return {
    name = "The Undercroft",
    order = 7,
    x = 175,
    y = 480,
    w = 270,
    h = 130,
    vendor = "undercroft",
    -- The desk: what this house says on the way in, and the rooms it offers (models/counter.lua).
    counter = "conversation_undercroft_counter",
    offers = {
        -- The town's own counter: plain kit and three rolled rows a day, any class, no class level in
        -- the way (models/market.lua). Its own vendor, so its racks are its racks -- see the header.
        { answer = "counter", panel = "shop", vendor = "market", gate = { trips = 1 } },
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
    },
    description = "No sign, no door you'd notice. Everything here belonged to someone else.",
}
