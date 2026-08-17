return {
    name = "The Colosseum",
    order = 9,
    x = 40,
    y = 416,
    w = 270,
    h = 130,
    panel = "shop",
    vendor = "colosseum", -- fighter class; see data/vendors/colosseum.lua
    -- OPENS WHEN ITS CIRCLE FALLS (models/building.lua). This house IS one of the seven sins, and
    -- putting that circle's general down in the descent is what puts its shelf in the city.
    unlockCircle = true,
    unlockPrestige = 1,
    -- Shut until the debut is fought on its own sand (data/quests/colosseum/quest_colosseum_slot_01.lua). The tutorial hub
    -- opens with only the Cafe and the Quest Board among its shops; you cannot browse the fighters'
    -- shelf before you have stood in their arena. The debut also lifts prestige to 2, so this door and
    -- the neighbours that open at 2 all appear together the moment it is won. The gate does NOT hide the
    -- debut quest itself: Quest.available reads Building.vendorUnlockPrestige, which is still 1 (see
    -- models/building.lua and models/quest.lua).
    unlockQuest = "quest_colosseum_slot_01",
}
