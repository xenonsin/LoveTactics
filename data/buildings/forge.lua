-- The Forge: the city's one upgrade bench. Vendors sell; this is where every ladder is climbed and the
-- only door that spends materials (models/forge.lua, ui/panels/forge.lua).
--
-- IT ARRIVES ON THE FOURTH FLOOR (models/building.lua's `unlockDepth`), and it is the last of the city
-- to. What this bench spends is MATERIALS, salvaged a handful at a time out of the fighting
-- (models/spoils.lua) -- so a company three floors in is standing at a counter it cannot transact at,
-- reading a ladder for gear it has not found yet. Four floors is roughly where the stock is deep enough
-- that a rung is a real purchase rather than a number to look at, and by then the player has a weapon
-- they have decided they like, which is the only thing an upgrade bench is any use for.
--
-- IT USED TO OPEN WITH THE CITY, on the reasoning that an upgrade station the player cannot reach is the
-- same as no upgrade station -- which was the old unreachable blacksmith's problem and is a real one.
-- The gate here is depth rather than prestige, and depth is the one thing this mode hands out for free:
-- a company that keeps going down opens it without doing anything else.
--
-- Sits in the free card of the bottom row, between the Draft Yard and the Crucible.
return {
    name = "The Forge",
    order = 6,
    x = 835,
    y = 300,
    w = 270,
    h = 130,
    panel = "forge",
    description = "Every upgrade to every piece of gear is bought at this bench.",
    unlockDepth = 4, -- see models/building.lua
    unlockPrestige = 1,
}
