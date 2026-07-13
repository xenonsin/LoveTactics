-- Tests for item upgrade levels (models/item.lua) and the blacksmith/vendor upgrade paths: a +n
-- weapon's ability Power and a +n armor's defense scale with the level, the " +n" rides on the name,
-- and the forge/vendor spend the right resources. Headless.

local Item = require("models.item")
local Character = require("models.character")
local Player = require("models.player")
local Blacksmith = require("models.blacksmith")
local Vendor = require("models.vendor")

return {
    {
        name = "a +n weapon's Power resolves to that level's tuned value, and the name gains a suffix",
        fn = function()
            local curve = Item.defs.iron_sword.activeAbility.power -- the per-level list, 0..MAX_LEVEL
            assert(type(curve) == "table", "iron_sword Power is authored as a per-level table")
            local base = Item.instantiate("iron_sword")            -- level 0
            local up3 = Item.instantiate("iron_sword", 1, 3)       -- +3
            assert(base.activeAbility.power == curve[1], "level 0 resolves the first table entry")
            assert(up3.activeAbility.power == curve[4], "+3 resolves the level-3 entry (index 4)")
            assert(up3.activeAbility.power > base.activeAbility.power, "and it is stronger than the base")
            assert(up3.name == base.name .. " +3", "the name carries the +3 suffix, got " .. up3.name)
            assert(base.name:find("+") == nil, "a base item has no suffix")
        end,
    },
    {
        name = "a +n armor's defense and resists resolve to their level's tuned values",
        fn = function()
            local dcurve = Item.defs.chainmail.bonus.defense
            local rcurve = Item.defs.chainmail.resist.slash
            local up2 = Item.instantiate("chainmail", 1, 2)
            assert(up2.bonus.defense == dcurve[3], "+2 defense is the level-2 entry (index 3)")
            assert(up2.resist.slash == rcurve[3], "+2 slash resist is the level-2 entry")
            assert(up2.bonus.movement == -1, "a flat magnitude (the movement penalty) does not scale")
        end,
    },
    {
        name = "the level clamps to MAX_LEVEL (10) and a short table holds at its last entry",
        fn = function()
            assert(Item.MAX_LEVEL == 10, "the ceiling is ten")
            local curve = Item.defs.iron_sword.activeAbility.power
            local maxed = Item.instantiate("iron_sword", 1, 99) -- asks past the ceiling
            assert(maxed.level == 10, "the level is clamped to MAX_LEVEL")
            assert(maxed.activeAbility.power == curve[#curve], "and Power reads the final tuned entry")
        end,
    },
    {
        name = "primaryStat leads with the defining magnitude at the current level, with its label",
        fn = function()
            local v, label = Item.primaryStat(Item.instantiate("iron_sword", 1, 2))
            assert(label == "Power" and v == Item.defs.iron_sword.activeAbility.power[3],
                "a blade leads with its leveled Power")
            local dv, dlabel = Item.primaryStat(Item.instantiate("leather_armor"))
            assert(dlabel == "Defense" and dv == Item.defs.leather_armor.bonus.defense[1],
                "armor leads with its defense")
        end,
    },
    {
        name = "an ability item is forgeable at the vendor, not the blacksmith",
        fn = function()
            local spell = Item.instantiate("ability_fireball")
            assert(Item.isUpgradable(spell), "an ability can be upgraded (at its vendor)")
            assert(not Blacksmith.canForge(spell), "but not at the blacksmith")
            local sword = Item.instantiate("iron_sword")
            assert(Blacksmith.canForge(sword), "a weapon is forged at the blacksmith")
        end,
    },
    {
        name = "the blacksmith spends gold + materials and returns a leveled instance",
        fn = function()
            local player = Player.new()
            player.gold = 1000
            player.materials = { iron_scrap = 10 }
            local sword = Item.instantiate("iron_sword")

            local cost = Blacksmith.upgradeCost(sword)
            local gold0 = player.gold
            local mat0 = player.materials.iron_scrap
            local matId = next(cost.materials)

            local up = Blacksmith.upgrade(player, sword)
            assert(up and up.level == 1, "the forge returns a +1 instance")
            assert(player.gold == gold0 - cost.gold, "gold was spent")
            assert(player.materials[matId] == mat0 - cost.materials[matId], "materials were spent")
        end,
    },
    {
        name = "the blacksmith refuses an upgrade the player can't pay for, charging nothing",
        fn = function()
            local player = Player.new()
            player.gold = 0
            player.materials = {}
            local sword = Item.instantiate("iron_sword")
            local up, reason = Blacksmith.upgrade(player, sword)
            assert(up == nil and (reason == "gold" or reason == "materials"), "the forge refuses, got " .. tostring(reason))
            assert(player.gold == 0, "and charges nothing")
        end,
    },
    {
        name = "a vendor hones an ability for gold, gated by standing",
        fn = function()
            local player = Player.new()
            player.gold = 1000
            -- Rank 1 (no reputation) unlocks up to +2; +3 needs higher standing.
            local spell = Item.instantiate("ability_fireball") -- mage class -> arcanum
            local cost1 = Vendor.abilityUpgradeCost(spell, 1)
            assert(cost1 and not cost1.locked, "the first upgrade is available at rank 1")

            local up = Vendor.upgradeAbility(player, "arcanum", spell)
            assert(up and up.level == 1, "the vendor returns a +1 spell")
            assert(player.gold == 1000 - cost1.gold, "gold was spent, no materials")

            -- A high-level upgrade is locked behind rank until the standing is earned.
            local hi = Item.instantiate("ability_fireball", 1, 3) -- already +3, next is +4
            local cost4 = Vendor.abilityUpgradeCost(hi, 1)
            assert(cost4.locked, "+4 is locked at rank 1")
            local up4, reason = Vendor.upgradeAbility(player, "arcanum", hi)
            assert(up4 == nil and reason == "locked", "and the vendor refuses it, got " .. tostring(reason))
        end,
    },
}
