-- The Dueling Grounds: where you fight other players' teams rather than the world's.
--
-- Gated on the Colosseum debut (data/quests/colosseum/quest_colosseum_slot_01.lua) rather than on prestige, which is the
-- first building in the city to open that way. The reason is fiction as much as pacing: the debut is
-- the fight that gives the nameless survivor a name, and until someone HAS a name there is nobody
-- for another house to be matched against. You do not get here by growing richer; you get here by
-- having stood on the sand once.
--
-- Narrower than its neighbours because it is squeezed into the last gap on the bottom row, beside
-- the Cafe.
return {
    name = "Dueling Grounds",
    order = 8,
    x = 970,
    y = 268,
    w = 180,
    h = 130,
    panel = "pvp",
    unlockPrestige = 1,
    unlockQuest = "quest_colosseum_slot_01", -- see models/building.lua
}
