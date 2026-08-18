-- Building blueprint. THE MARKETS: the door onto every shelf in the city, and the only one.
--
-- WHY THE SHOPS LEFT THE CITY BOARD. Fifteen cards on one screen, and seven of them were the same kind
-- of thing -- a shelf you browse -- while eleven of the fifteen were shut on a fresh save. The city read
-- as a wall of locked plates rather than a town, and the one card a new player could actually use was
-- buried among them. So the shelves went behind this one card and onto a board of their own
-- (`district = "market"`, models/building.lua), which took the city from four rows to two and left every
-- card on it something you can walk into.
--
-- IT IS NEVER SHUT, and it does not need to be: the General Store is standing in there on day one, and
-- the seven houses are the things that arrive. A Markets card that waited for its first tenant would be
-- a locked door in front of an open shop.
--
-- `state` rather than `panel`: the market is a whole screen, like the Gate. A pop-up would have to host
-- a second pop-up -- the shop panel opens over it -- and two stacked overlays over a painted city is a
-- worse place to read a shelf than a room of its own.
return {
    name = "The Markets",
    order = 4,
    x = 835,
    y = 120,
    w = 270,
    h = 130,
    state = "markets",
    description = "Seven houses around one square, each shut until you run its work.",
    unlockPrestige = 1,
}
