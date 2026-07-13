-- Tests that the v2 save schema round-trips item upgrade levels and forging materials (models/save).
-- Pure: exercises Save.snapshot -> Save.restore without touching disk. Headless.

local Save = require("models.save")
local Player = require("models.player")
local Item = require("models.item")

return {
    {
        name = "a save round trip preserves a forged item's +n level",
        fn = function()
            local player = Player.new()
            -- Drop a +3 sword into the first roster member's first grid cell.
            player.roster[1].inventory[1] = Item.instantiate("iron_sword", 1, 3)

            local restored = Save.restore(Save.snapshot(player))
            assert(restored, "the snapshot restores")
            local item = restored.roster[1].inventory[1]
            assert(item.id == "iron_sword", "the sword survives")
            assert(item.level == 3, "its +3 level survives, got " .. tostring(item.level))
            -- And the level is re-baked, not just stored: its damage reflects the upgrade.
            local base = Item.instantiate("iron_sword")
            assert(item.activeAbility.damage > base.activeAbility.damage, "the restored item is actually stronger")
        end,
    },
    {
        name = "a save round trip preserves forging materials",
        fn = function()
            local player = Player.new()
            player.materials = { iron_scrap = 7, steel_ingot = 2 }

            local restored = Save.restore(Save.snapshot(player))
            assert(restored.materials.iron_scrap == 7, "iron scrap survives")
            assert(restored.materials.steel_ingot == 2, "steel ingots survive")
        end,
    },
    {
        name = "a stash item's level round-trips too",
        fn = function()
            local player = Player.new()
            player.stash = { Item.instantiate("chainmail", 1, 2) }

            local restored = Save.restore(Save.snapshot(player))
            assert(restored.stash[1].level == 2, "the stashed +2 armor keeps its level")
        end,
    },
}
