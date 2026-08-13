return {
    name = "The Bastion",
    order = 6,
    x = 350,
    y = 340,
    w = 270,
    h = 140,
    panel = "shop",
    vendor = "bastion", -- knight class
    unlockPrestige = 2,
    -- Prestige 2 alone put this door up the moment the debut paid out, which is one quest into the
    -- game: the tutorial handed the player a city of six shops before they had run anything. The
    -- padded card is where the campaign actually opens (data/quests/colosseum/quest_colosseum_slot_02.lua)
    -- and it is the gate the Cathedral, this house and the Lodge now share, so the opening funnel is
    -- two Colosseum quests wide and the city arrives after them rather than during them.
    -- The gate does NOT hide this house's work: Quest.available reads Building.vendorUnlockPrestige,
    -- which is still 2, so the line head carries the same requirement itself (models/quest.lua,
    -- data/quests/bastion/quest_bastion_slot_01.lua). See data/buildings/colosseum.lua.
    unlockQuest = "quest_colosseum_slot_02",
}
