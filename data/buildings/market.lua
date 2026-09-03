-- THE MARKET: the town's own counter, and the card that is never shut.
--
-- The square used to stand in this slot -- a board of its own holding seven shopfronts, one per house,
-- each waiting on an errand found underground. That gate was unsatisfiable and the doors came out with
-- it; this counter is what took their place. The seven are back next door on the gate they were always
-- missing (data/buildings/houses.lua -- level 1 of the house's own class), and this card stayed, because
-- what it does is the half a ladder cannot do: sell a company that has climbed NOTHING its first blade
-- and its bandages, on the first morning, with no door in the way.
--
-- IT IS ON THE CITY BOARD RATHER THAN BEHIND THE SQUARE, and that is the division stated in the layout.
-- The plaza is where you go before going down; the square is a thing you earned. Putting the always-open
-- counter behind the earned door would gate the opening kit on a class level.
--
-- NO UNLOCK GATE OF ANY KIND. It is open on the first morning of a fresh save, which is deliberate:
-- what the market sells is bounded by the company's tier and by what it can afford (models/market.lua),
-- and a shop that is SHUT teaches nothing while a shop full of things you cannot afford yet teaches the
-- whole ladder at a glance.
return {
    name = "The Market",
    order = 4,
    x = 835,
    y = 120,
    w = 270,
    h = 130,
    panel = "shop",
    vendor = "market",
    description = "Everything anyone came back up with, and a few things nobody did.",
}
