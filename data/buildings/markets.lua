-- Building blueprint. THE MARKETS: the door onto every shelf in the city, and the only one.
--
-- WHY THE SHOPS LEFT THE CITY BOARD. Fifteen cards on one screen, and seven of them were the same kind
-- of thing -- a shelf you browse -- while eleven of the fifteen were shut on a fresh save. The city read
-- as a wall of locked plates rather than a town, and the one card a new player could actually use was
-- buried among them. So the shelves went behind this one card and onto a board of their own
-- (`district = "market"`, models/building.lua), which took the city from four rows to two and left every
-- card on it something you can walk into.
--
-- IT WAITS FOR ITS FIRST TENANT (models/errand.lua's Errand.anyDoorOpen). Every one of the seven houses
-- is shut on a fresh save and there is no eighth -- a General Store stood here for a day and was cut,
-- because the road is the shop -- so a company that has opened none of them was pressing this card to
-- reach a square of seven locked plates. That is a door onto a corridor of doors, and the one thing it
-- can teach ("come back when you have done some work") is a sentence the card itself can say by not
-- being there.
--
-- So it arrives with whichever house the player opens first, and the six still shut behind it then read
-- as what is LEFT to open rather than as the whole of what the market is. Note the card was written the
-- other way round for most of its life -- "a Markets card that waited for its first tenant would be a
-- locked door in front of an open shop" -- and that was true while the General Store was in there. It
-- is not any more, and this is the same argument reaching the opposite conclusion off the changed fact.
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
    unlockAnyErrand = true, -- see models/building.lua
    unlockPrestige = 1,
}
