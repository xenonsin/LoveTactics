-- Encounter blueprint. A reward stop rather than a fight: a cache of loot. Uncommon (low weight) so it
-- feels like a find.
--
-- WHAT IS ACTUALLY IN ONE IS NOT HERE ANY MORE, and that is the change worth reading. A chest on a
-- descent floor deals two or three pieces at THAT FLOOR'S OWN RANK (Spoils.cache, pinned onto the cell
-- by states/game.lua's treasure branch), because a stop four tiles off the road has to be worth the
-- detour its marker has been advertising -- and because when the lid turns out to be alive, those
-- pieces are the mimic's kit as well as its drop (models/mimic.lua). A one-item chest stands up as a
-- box with a bite and nothing else.
--
-- SO THIS `loot` IS THE FLOOR, not the contents. It is what a board with no DEPTH to draw against
-- hands over -- a campaign road, a scripted leg, a fixture -- and it is deliberately the humblest
-- thing in the catalogue: a chest that pays nothing at all would be a marker that lied, and a chest
-- that paid gear off a ladder its board does not stand on would be the shelf leaking into the
-- campaign. A stackable, so it merges tidily in the stash.
--
-- A route may still override it per placement (`loot` on the placement), and that wins over everything:
-- the flight leg's first chest hands over an exact teaching kit and nothing may re-roll it.
return {
    name = "Treasure Chest",
    kind = "treasure",
    weight = 1,
    minDay = 1,
    loot = { "consumable_healing_potion" },
}
