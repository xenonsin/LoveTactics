return {
    name = "The Colosseum",
    order = 3,
    x = 660,
    y = 150,
    w = 270,
    h = 140,
    panel = "shop",
    vendor = "colosseum", -- fighter class; see data/vendors/colosseum.lua
    unlockPrestige = 1,
    -- Shut until the debut is fought on its own sand (data/quests/arena_debut.lua). The tutorial hub
    -- opens with only the Market and the Quest Board among its shops; you cannot browse the fighters'
    -- shelf before you have stood in their arena. The debut also lifts prestige to 2, so this door and
    -- the neighbours that open at 2 all appear together the moment it is won. The gate does NOT hide the
    -- debut quest itself: Quest.available reads Building.vendorUnlockPrestige, which is still 1 (see
    -- models/building.lua and models/quest.lua).
    unlockQuest = "arena_debut",
}
