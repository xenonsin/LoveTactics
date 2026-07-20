-- The Dueling Grounds: where you fight other players' teams rather than the world's.
--
-- Gated on the Colosseum debut (data/quests/arena_debut.lua) rather than on prestige, which is the
-- first building in the city to open that way. The reason is fiction as much as pacing: the debut is
-- the fight that gives the nameless survivor a name, and until someone HAS a name there is nobody
-- for another house to be matched against. You do not get here by growing richer; you get here by
-- having stood on the sand once.
--
-- Narrower than its neighbours because it is squeezed into the last gap on the bottom row, beside
-- the market.
return {
    name = "Dueling Grounds",
    order = 12,
    x = 1090,
    y = 530,
    w = 180,
    h = 140,
    panel = "pvp",
    unlockPrestige = 1,
    unlockQuest = "arena_debut", -- see models/building.lua
}
