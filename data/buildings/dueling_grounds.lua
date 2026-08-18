-- The Dueling Grounds: where you fight other players' teams rather than the world's.
--
-- YOU GET HERE BY HAVING STOOD ON THE SAND ONCE, not by growing richer, and that has always been the
-- rule here -- this was the first door in the city to open on a deed rather than a threshold. The deed
-- was the Colosseum debut (data/quests/colosseum/quest_colosseum_slot_01.lua): the fight that gives the
-- nameless survivor a name, because until someone HAS a name there is nobody for another house to be
-- matched against.
--
-- THAT QUEST CANNOT BE FINISHED ANY MORE. The Quest Board is retired (models/building.lua's RETIRED)
-- and its 91 quests with it, so the gate named a deed with no way left to perform it and this card sat
-- shut for the life of every save, quoting a prestige number that was not even the gate it was asked.
--
-- So it opens on the sand as the descent has it: the Colosseum's own first job, the piece of work that
-- house posts on a floor for anybody willing to walk to it. Same sentence, same fiction, and a deed the
-- player can actually go and do. It is the only door that names somebody ELSE'S errand -- it keeps no
-- shelf and posts no work of its own -- which is why `unlockErrand` takes a vendor id here and a bare
-- `true` everywhere else.
--
-- Full width now, in the far corner of the plaza. It was squeezed narrow into a gutter when fifteen
-- cards shared this board; the shops left for the market and the city rebuilt itself around the Gate,
-- so there is a whole slot for it (models/building.lua's GRID).
return {
    name = "Dueling Grounds",
    order = 8,
    x = 835,
    y = 480,
    w = 270,
    h = 130,
    panel = "pvp",
    unlockErrand = "colosseum", -- see models/building.lua
    unlockPrestige = 1,
}
