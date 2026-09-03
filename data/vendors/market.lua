-- THE MARKET: the one shop, and the shop that replaced seven.
--
-- The city used to hold a house per class -- the Bastion, the Arcanum, the Cathedral, the Colosseum,
-- the Crucible, the Hunter's Lodge, the Undercroft -- each with its own shelf, its own ladder of
-- finished work, and its own door that had to be opened underground before any of it could be reached.
-- The houses are classes now (models/class.lua, docs/classes.md); what a class is is something a
-- BODY climbs, not a room you unlock. So the rooms came out and the counter stayed.
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
