-- THE MARKET: the town's own counter, and the card the first descent opens.
--
-- The square used to stand in this slot -- a board of its own holding seven shopfronts, one per house,
-- each waiting on an errand found underground. That gate was unsatisfiable and the doors came out with
-- it; this counter is what took their place. The seven are back next door on the gate they were always
-- missing (data/buildings/houses.lua -- level 1 of the house's own class), and this card stayed, because
-- what it does is the half a ladder cannot do: sell a company that has climbed nothing its first blade
-- and its bandages, from any class, with no class level in the way.
--
-- IT IS ON THE CITY BOARD RATHER THAN BEHIND THE SQUARE, and that is the division stated in the layout.
-- The plaza is where you go before going down; the square is a thing you earned. Putting the town's own
-- counter behind the earned door would gate the opening kit on a class level.
--
-- IT WAITS FOR THE FIRST DESCENT (models/building.lua's `unlockDepth`), and that is the only gate it
-- keeps. It was open on the first morning of a fresh save for a long time, and the argument was sound on
-- its own terms: what the counter sells is bounded by the company's tier and by what it can afford
-- (models/market.lua), so a shelf full of things you cannot pay for teaches the whole ladder at a glance.
-- What that argument missed is that the first morning has exactly ONE thing to teach and it is the stair.
-- A plaza that opens on a shelf and a hole in the ground is asking the player which of the two the game
-- is, and the shelf is the wrong answer -- doubly so when almost nothing is ON it yet: a counter stocks a
-- ware only once the company has carried one out (models/vendor.lua's `lockReason`), so a shop opened
-- before the first floor is a room of locked rows explaining a ladder nobody has stepped onto.
--
-- So the city opens on the Armory and the Rift, the player goes down, and the counter is standing there
-- on the way back up -- coached by the plaza the way every other earned door is (states/hub.lua's
-- coachNextDoor), at the exact moment there is loot to sell and gold to spend it.
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
    unlockDepth = 1, -- see above, and models/building.lua
}
