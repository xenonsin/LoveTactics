-- Building blueprint. THE HOUSES: the square the class shelves stand around, and the door onto all
-- seven of them.
--
-- WHY THE SHELVES ARE NOT ON THE PLAZA. Seven more cards on a nine-slot board, and seven of them the
-- same kind of thing -- a shelf you browse. That reading is what moved the shops off the city board the
-- first time (models/building.lua), and it is still true. One card, and behind it a board of its own.
--
-- IT WAITS FOR ITS FIRST TENANT (`unlockAnyHouse`). Every house is shut on a fresh save -- each opens on
-- level 1 of its own class -- so a company that has climbed nothing would be pressing this card to reach
-- a square of seven locked plates. That is a door onto a corridor of doors, and the one thing it can
-- teach ("come back when you have played something") is a sentence the card says by not being there.
--
-- IT IS NOT THE MARKET, and the plaza carries both. The Market is the town's counter: plain kit and
-- three rolled rows a day, open on the first morning, any class (models/market.lua). A house is one
-- class's whole ladder, never rolled, growing as that class does. Day-one shopping and earned shopping.
--
-- `state` rather than `panel`: the square is a whole screen, like the Gate. A pop-up would have to host
-- a second pop-up -- the shop panel opens over it -- and two stacked overlays over a painted city is a
-- worse place to read a shelf than a room of its own.
return {
    name = "The Houses",
    order = 3,
    x = 175,
    y = 120,
    w = 270,
    h = 130,
    state = "houses",
    description = "Seven shelves around one square, each opened by climbing its class.",
    unlockAnyHouse = true, -- see models/building.lua
    unlockPrestige = 1,
}
