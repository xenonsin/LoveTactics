-- Tests that a save round-trips its schema through Save.snapshot -> Save.restore (models/save):
-- item upgrade levels, forging materials, recipe tiers, the pinned default action, and the created
-- avatar (player body/name + a per-character display name). Pure: no disk. Headless.

local Save = require("models.save")
local Player = require("models.player")
local Item = require("models.item")

return {
    {
        name = "the created avatar's body and typed name round-trip",
        fn = function()
            local player = Player.new()
            player.body = 2
            -- The name is banked on the player at creation AND copied onto the avatar instance, which
            -- is what the roster and dialogue read. Both survive.
            player.name = "Wend"
            player.roster[1].name = "Wend"

            local restored = Save.restore(Save.snapshot(player))
            assert(restored, "the snapshot restores")
            assert(restored.body == 2, "the chosen body survives, got " .. tostring(restored.body))
            assert(restored.name == "Wend", "the typed name survives on the player, got " .. tostring(restored.name))
            assert(restored.roster[1].name == "Wend",
                "the avatar's typed name survives, got " .. tostring(restored.roster[1].name))
        end,
    },
    {
        name = "a character showing its blueprint name stores no override (clean diff)",
        fn = function()
            local player = Player.new()
            local snap = Save.snapshot(player)
            -- roster[1] never got a custom name, so its snapshot must not carry one.
            assert(snap.roster[1].name == nil, "an un-renamed character must not persist a name override")
            -- ...and it still loads back to its blueprint name.
            local restored = Save.restore(snap)
            local Character = require("models.character")
            assert(restored.roster[1].name == Character.defs[restored.roster[1].id].name,
                "an un-renamed character keeps its blueprint name")
        end,
    },
    {
        name = "a save round trip preserves a forged item's +n level",
        fn = function()
            local player = Player.new()
            -- Drop a +3 sword into the first roster member's first grid cell.
            player.roster[1].inventory[1] = Item.instantiate("weapon_iron_sword", 1, 3)

            local restored = Save.restore(Save.snapshot(player))
            assert(restored, "the snapshot restores")
            local item = restored.roster[1].inventory[1]
            assert(item.id == "weapon_iron_sword", "the sword survives")
            assert(item.level == 3, "its +3 level survives, got " .. tostring(item.level))
            -- And the level is re-baked, not just stored: its damage reflects the upgrade.
            local base = Item.instantiate("weapon_iron_sword")
            assert(item.activeAbility.damage > base.activeAbility.damage, "the restored item is actually stronger")
        end,
    },
    {
        name = "a save round trip preserves forging materials",
        fn = function()
            local player = Player.new()
            player.materials = { material_iron_scrap = 7, material_steel_ingot = 2 }

            local restored = Save.restore(Save.snapshot(player))
            assert(restored.materials.material_iron_scrap == 7, "iron scrap survives")
            assert(restored.materials.material_steel_ingot == 2, "steel ingots survive")
        end,
    },
    {
        name = "a stash item's level round-trips too",
        fn = function()
            local player = Player.new()
            player.stash = { Item.instantiate("armor_chainmail", 1, 2) }

            local restored = Save.restore(Save.snapshot(player))
            assert(restored.stash[1].level == 2, "the stashed +2 armor keeps its level")
        end,
    },
    {
        name = "consumable recipe tiers round-trip, and an id no longer in data/ is dropped",
        fn = function()
            local player = Player.new()
            player.recipes = { consumable_acid_bomb = 3, ghost_tonic = 2 } -- ghost_tonic is not a real item id

            local restored = Save.restore(Save.snapshot(player))
            assert(restored.recipes.consumable_acid_bomb == 3, "the acid_bomb recipe tier survives")
            assert(restored.recipes.ghost_tonic == nil, "a tier for a vanished item is dropped")
        end,
    },
    {
        name = "a character's pinned default action slot round-trips (with legacy + empty fallbacks)",
        fn = function()
            local player = Player.new()
            -- Pin a second weapon in cell 4 as the first roster member's default action.
            player.roster[1].inventory[4] = Item.instantiate("weapon_iron_bow")
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
