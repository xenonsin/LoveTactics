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
    {
        name = "consumable recipe tiers round-trip, and an id no longer in data/ is dropped",
        fn = function()
            local player = Player.new()
            player.recipes = { acid_bomb = 3, ghost_tonic = 2 } -- ghost_tonic is not a real item id

            local restored = Save.restore(Save.snapshot(player))
            assert(restored.recipes.acid_bomb == 3, "the acid_bomb recipe tier survives")
            assert(restored.recipes.ghost_tonic == nil, "a tier for a vanished item is dropped")
        end,
    },
    {
        name = "a character's pinned default action slot round-trips (with legacy + empty fallbacks)",
        fn = function()
            local player = Player.new()
            -- Pin a second weapon in cell 4 as the first roster member's default action.
            player.roster[1].inventory[4] = Item.instantiate("iron_bow")
            player.roster[1].defaultActionSlot = 4

            local snap = Save.snapshot(player)
            local restored = Save.restore(snap)
            assert(restored.roster[1].defaultActionSlot == 4, "the pinned slot survives a round trip")

            -- A save from before the default-weapon -> default-action rename keeps its pin: the legacy
            -- defaultWeaponSlot key is read when the new one is absent.
            snap.roster[1].defaultActionSlot = nil
            snap.roster[1].defaultWeaponSlot = 4
            local legacy = Save.restore(snap)
            assert(legacy.roster[1].defaultActionSlot == 4, "a legacy defaultWeaponSlot still pins the action")

            -- A save with neither field restores to nil (the auto pick), not a crash.
            snap.roster[1].defaultWeaponSlot = nil
            local restored2 = Save.restore(snap)
            assert(restored2.roster[1].defaultActionSlot == nil, "a save without either field loads as nil")
        end,
    },
}
