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
-- THE SUPPER ARRIVES ON THE FOURTH TRIP HOME (Offer.SCHEDULE). A meal is a decision made against a road you already
-- know the shape of -- which floor, how deep, how long the company will be down there before it eats
-- again -- and on the morning of the first descent the player knows none of that. A few trips is the whole
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
        -- THE SHELF OPENS ON THE CITY SCHEDULE (models/offer.lua's Offer.SCHEDULE): one house's shelf per
        -- trip home, in a fixed order, unless a body unlocks this house's class first -- that pulls
        -- the shelf into the next trip's slot. Once open it stays open, and it announces its house:
        -- the plaza grows by one shopfront a homecoming. A class level still buys DEPTH and nothing
        -- else (Quest.shelfRung): level 0 is rung 0, the bottom band.
        { answer = "shelf", panel = "shop", gate = { city = "hunters_lodge.shelf" } },
        -- The kitchen keeps its own vendor: its portrait, its name and its one-time greeting all hang
        -- off `cafe`, and it sells no items at all (data/vendors/cafe.lua).
        { answer = "supper", panel = "cafe", vendor = "cafe", gate = { city = "hunters_lodge.supper" } },
        -- THE HIRING BOARD IS PARKED (2026-10-15). It sold blank strangers the player builds, and the
        -- avatar became that same thing once its people and class were chosen on the Charter's roll
        -- (states/character_creation.lua): two kinds of voiceless custom body in one roster. The company
        -- grows through its written companions instead. models/hire.lua and ui/panels/hire.lua stay on
        -- disk and still load, and the desk line still names `hire`, so lifting the park is deleting the
        -- `parked` key below (models/offer.lua) and leaving the sixth-trip gate it sat beside.
        { answer = "hire", panel = "hire", gate = { parked = true, trips = 6 } },
    },
    description = "Bows, traps, and one hot supper before the road.",
}
