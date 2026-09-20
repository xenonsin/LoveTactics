-- THE CLINGING HAND: the whole curse is that you cannot put it down.
--
-- NO STAT PENALTY AT ALL, AND THAT IS THE DESIGN RATHER THAN AN UNFINISHED FILE. The 3x3 grid is the
-- whole of what a body can reach (models/item.lua's bag block), so a cell is the scarcest thing the
-- player owns -- and a piece nailed into one of the nine is a real cost whose size the PLAYER sets by
-- what got nailed. On a good sword it is nearly free. On the junk blade you were carrying out to sell
-- it is a ninth of a body, for two trips or eighty gold.
--
-- SO IT IS THE SHALLOWEST HEX IN THE RIFT, and it is the one that teaches the room. A player meets it
-- early, reads a tooltip saying the piece cannot be moved, walks into the Cathedral and finds out what
-- a rite is -- all without having been hurt in a fight. Every deeper hex is this one plus a bite.
return {
    name = "The Clinging Hand",
    description = "This piece cannot be moved, stowed, sold or taken from you.",
    binds = true,
    depth = 1,
    fee = 80,
}
