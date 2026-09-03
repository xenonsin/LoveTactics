-- THE MARKET: the town's own counter, and the shop that is open on the first morning.
--
-- IT REPLACED THE SEVEN HOUSES AND NOW STANDS BESIDE THEM. The city used to hold a house per class --
-- the Bastion, the Arcanum, the Cathedral, the Colosseum, the Crucible, the Hunter's Lodge, the
-- Undercroft -- each behind a door that had to be opened underground before any of it could be reached,
-- which is a gate nobody could satisfy. They came out, this counter took their place, and they are back
-- on a board of their own with the gate they were always missing: level 1 of the house's own class
-- (data/buildings/houses.lua).
--
-- SO WHAT IS THIS ONE FOR, with the seven ladders open again. It is the shop for a company that has
-- climbed nothing yet, and the shop nobody has to walk past a ladder to use: plain kit and three rolled
-- rows a day, any class, never gated. A house sells one class's whole ladder, deepening as that class
-- does. Day-one shopping and earned shopping.
--
-- `sellsAll` is the whole of its shelf contract, and it is the mirror of the Cafe's `sells = false`:
-- Vendor.sells accepts everything here, and what a ware costs the player is decided by its rung and its
-- price rather than by which house was willing to stock it. Nothing can drift ON or OFF this counter by
-- acquiring or losing a class, which is exactly the property the seven shelves could not have.
--
-- WHAT IT ACTUALLY OFFERS on any given morning is not this file's business -- see models/market.lua.
-- Two racks: a standing core that is always there, so a bad roll is never a wasted walk into town, and
-- a rotation dealt fresh each day against how far the company has got. The blueprint holds the
-- shopkeeper (the name, the description, the greeting) because that is what a vendor def is for.
return {
    name = "The Market",
    sellsAll = true, -- every class's wares on one counter; models/market.lua decides which are out today
    description = "Everything anyone came back up with, and a few things nobody did.",
}
