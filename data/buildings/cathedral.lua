return {
    name = "The Cathedral",
    order = 4,
    x = 970,
    y = 150,
    w = 270,
    h = 140,
    panel = "shop",
    vendor = "cathedral", -- priest class
    unlockPrestige = 1,
    -- Held shut through the tutorial, same as the Colosseum: before the debut on the sand the hub
    -- offers only the Market and the Quest Board. The debut raises prestige to 2, which is where the
    -- Cathedral's own quests begin (fallen_confessor, haunted_mill), so the shop and its work open on
    -- the same beat. See data/buildings/colosseum.lua for why this does not hide the debut quest.
    unlockQuest = "arena_debut",
}
