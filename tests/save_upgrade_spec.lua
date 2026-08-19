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
        -- THE THREE THINGS THE CITY GROWS ON (models/building.lua's gate table). Each is a fact about
        -- the company rather than about the campaign, each opens a building, and each is a field nothing
        -- else in the save would notice going missing -- a door that quietly stopped opening after a
        -- quit-and-continue is exactly the failure that has no other symptom.
        name = "the depth record, the wound mark and the hiring purse round-trip",
        fn = function()
            local Descent = require("models.descent")
            local Voucher = require("models.voucher")
            local Wound = require("models.wound")

            local player = Player.new()
            Descent.reached(player, 6)
            Wound.inflict(player, { { id = "character_rowan" } })
            Voucher.stake(player, "character_saber")
            Voucher.grant(player, 2)

            local restored = Save.restore(Save.snapshot(player))
            assert(Descent.deepest(restored) == 6,
                "the depth record survives, got " .. tostring(Descent.deepest(restored)))
            assert(Wound.everWounded(restored), "the wound mark survives")
            -- THE HIRING PURSE (models/voucher.lua), which is a COUNT: a token has no grade, so there
            -- is nothing to carry across but how many. Three here -- the sponsor stakes one and two are
            -- granted -- and a purse that reloaded short would silently rob the player.
            assert(Voucher.count(restored) == 3,
                "the purse survives a reload, got " .. Voucher.count(restored))
            assert(restored.staked == true,
                "the sponsor's clause stays paid: she does not stake a second time after a reload")
            assert(restored.riggedPull == "character_saber",
                "the opening pull is still rigged to the body the story picked")

            -- ...and paying the surgeon does not un-mark it. The ledger empties; the fact does not, or
            -- the city would lose the Inn the morning after it was used.
            Wound.mend(restored, "character_rowan")
            local again = Save.restore(Save.snapshot(restored))
            assert(#Wound.wounded(again) == 0, "the ledger is clear")
            assert(Wound.everWounded(again), "and the mark is one-way")
        end,
    },
    {
        -- A SAVE FROM BEFORE ANY OF THIS reads as a company that has never gone down, never been hurt
        -- and had nothing staked -- which is exactly what it is. Purely additive, so Save.VERSION does
        -- not move, which means this is the only thing standing between an old save and a crash.
        name = "an older save loads with no depth, no wound history and an empty purse",
        fn = function()
            local Descent = require("models.descent")
            local Voucher = require("models.voucher")
            local Wound = require("models.wound")

            local snap = Save.snapshot(Player.new())
            snap.deepest, snap.wounded, snap.staked = nil, nil, nil
            snap.vouchers, snap.bonds, snap.pulls, snap.pity = nil, nil, nil, nil

            local restored = Save.restore(snap)
            assert(Descent.deepest(restored) == 0, "no record to beat")
            assert(not Wound.everWounded(restored), "nor any bones ever set")
            assert(Voucher.count(restored) == 0, "nor anything in the hiring purse")
            assert(next(restored.bonds or {}) == nil, "nor anybody pulled twice")
            assert(restored.pulls == 0 and restored.pity == 0, "and the pull ledger reads as unused")
            assert(restored.staked == false,
                "a save from before the stake existed has not been paid for, which is what it is")
        end,
    },
    {
        -- `staked` WAS A LIST AND IS A BOOLEAN, which is the one field here that changed SHAPE rather
        -- than merely appearing. An older save recorded the bodies the sponsor had stood in the hall;
        -- the hall does not hold bodies any more, so what survives is the single fact the flag is for --
        -- has her clause been made good. A truthy table reads as yes, because that save's sponsor had
        -- already paid and must not pay again.
        name = "a save whose staked field is still a list loads as a sponsor who has already paid",
        fn = function()
            local Voucher = require("models.voucher")
            local snap = Save.snapshot(Player.new())
            snap.staked = { "character_saber" }

            local restored = Save.restore(snap)
            assert(restored.staked == true, "an old list-shaped stake reads as paid")
            assert(not Voucher.stake(restored, "character_saber"),
                "...so she is not asked for a second voucher on load")
        end,
    },
    {
        name = "visited-vendor and discipline-announced flags round-trip",
        fn = function()
            local player = Player.new()
            player.visitedVendors.colosseum = true
            player.announcedDisciplines.warlord = true
            player.announcedDisciplines.champion = true

            local restored = Save.restore(Save.snapshot(player))
            assert(restored.visitedVendors.colosseum == true, "a visited vendor survives the round-trip")
            assert(restored.announcedDisciplines.warlord == true, "an announced discipline survives")
            assert(restored.announcedDisciplines.champion == true, "a second announced discipline survives")
            assert(restored.announcedDisciplines.ninja == nil, "an un-announced discipline is not invented")
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
        name = "visited-vendor flags round-trip, so a first-visit intro stays played",
        fn = function()
            local player = Player.new()
            assert(not Player.hasVisitedVendor(player, "colosseum"), "a fresh player has visited nobody")
            Player.markVendorVisited(player, "colosseum")
            assert(Player.hasVisitedVendor(player, "colosseum"), "marking a visit is remembered")

            local restored = Save.restore(Save.snapshot(player))
            assert(Player.hasVisitedVendor(restored, "colosseum"),
                "a visited vendor stays visited across a save/load (its intro never replays)")
            assert(not Player.hasVisitedVendor(restored, "cathedral"),
                "a vendor never opened is still unvisited")
        end,
    },
    {
        name = "a save from before visited-vendor flags loads with none visited",
        fn = function()
            local player = Player.new()
            local snap = Save.snapshot(player)
            snap.visitedVendors = nil -- an older save carried no such field
            local restored = Save.restore(snap)
            assert(restored, "the older snapshot still restores")
            assert(not Player.hasVisitedVendor(restored, "colosseum"),
                "an absent field reads as unvisited, not a crash")
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
