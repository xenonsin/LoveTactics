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
    -- Held shut a slot longer than the Colosseum, and the reason is the story: the player does not walk
    -- into this building, they are CARRIED into it. The padded card
    -- (data/quests/colosseum/quest_colosseum_slot_02.lua) ends with the whole company dead on the sand
    -- and its epilogue opens on a Cathedral ceiling, with an acolyte explaining who paid for the rite
    -- that brought them back. That scene is the door. Before it the hub has no Cathedral in it at all,
    -- so the first time the player ever sees the place is from a slab, which is worth more than a shop
    -- front they browsed a quest earlier. It also puts Amana on the roster before her own house opens,
    -- which is the whole point of moving her recruit here.
    -- See data/buildings/colosseum.lua for why this does not hide the quests behind it.
    unlockQuest = "quest_colosseum_slot_02",
}
