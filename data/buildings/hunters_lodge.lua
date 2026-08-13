return {
    name = "Hunter's Lodge",
    order = 5,
    x = 40,
    y = 340,
    w = 270,
    h = 140,
    panel = "shop",
    vendor = "hunters_lodge", -- hunter class
    unlockPrestige = 2,
    -- Same gate as the Bastion and the Cathedral, and for the same reason: prestige 2 is one quest
    -- into the campaign, so this door was arriving with the debut's payout. It waits on the padded
    -- card now (data/quests/colosseum/quest_colosseum_slot_02.lua). See data/buildings/bastion.lua for
    -- the whole note, and data/quests/hunters_lodge/quest_hunters_lodge_slot_01.lua for the matching
    -- requirement on the work behind it, which this field does not gate on its own.
    unlockQuest = "quest_colosseum_slot_02",
}
