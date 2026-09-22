-- HUNTER'S LODGE: the hunters' house, and where the company eats.
--
-- ITS SHELF is bows, traps and field kit from people who work outdoors, deepening as the roster's hunter
-- level climbs (Quest.shelfRung) rather than opening whole.
--
-- AND ITS SECOND ROOM IS THE CAFE -- one supper before the road, worn by the whole company for the whole
-- expedition (models/meal.lua, docs/meals.md). Gluttony's house, and the one door in the city with a
-- reason to have meat in it: they ask what you killed before they ask your name, and then they cook it.
-- The kitchen keeps its own keeper and its own greeting; only its card went (models/offer.lua).
--
-- THE SUPPER ARRIVES ON THE SECOND TRIP HOME. A meal is a decision made against a road you already
-- know the shape of -- which floor, how deep, how long the company will be down there before it eats
-- again -- and on the morning of the first descent the player knows none of that. Two trips is the whole
-- of the teaching: the company has been under, come up hungry, and the supper is now an answer to a
-- question they have.
return {
    name = "Hunter's Lodge",
    order = 6,
    x = 835,
    y = 300,
    w = 270,
    h = 130,
    vendor = "hunters_lodge",
    -- The desk: what this house says on the way in, and the rooms it offers (models/counter.lua).
    counter = "conversation_hunters_lodge_counter",
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
        -- The kitchen keeps its own vendor: its portrait, its name and its one-time greeting all hang
        -- off `cafe`, and it sells no items at all (data/vendors/cafe.lua).
        { answer = "supper", panel = "cafe", vendor = "cafe", gate = { trips = 2 } },
    },
    description = "Bows, traps, and one hot supper before the road.",
}
