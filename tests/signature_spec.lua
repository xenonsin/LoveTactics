-- Tests for signature relics: a character's innate reaction is no longer a blueprint `traits`
-- property but a BOUND item (Item.isBound) seeded into the loadout grid, delivering its trait through
-- the grid (models/trait.lua). The relic can never be moved, stowed, sold, or stolen -- only forged --
-- and it survives a save round trip (and is re-seeded for a save that predates it). Headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Trait = require("models.trait")
local Blacksmith = require("models.blacksmith")
local Vendor = require("models.vendor")
local Player = require("models.player")
local Save = require("models.save")

local function arena(cols, rows)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

return {
    {
        name = "instantiate seats the bound signature relic in the center, carrying the innate trait",
        fn = function()
            local knight = Character.instantiate("character_knight")
            local relic = knight.inventory[5]
            assert(relic and relic.id == "armor_sworn_aegis", "the Sworn Aegis sits in the center cell (5)")
            assert(Item.isBound(relic), "the relic is bound")
            assert(relic.traits and relic.traits[1] == "trait_oathward", "and it carries the Knight's Oathward")
            assert(knight.traits == nil, "the character no longer carries a `traits` property")
            -- The positional grid placed the surrounding items exactly where authored.
            assert(knight.inventory[1].id == "weapon_iron_mace", "cell 1 holds the authored weapon")
            assert(knight.inventory[2].id == "armor_chainmail", "cell 2 holds the authored armor")

            -- A boss is delivered its rule the same way.
            local boss = Character.instantiate("character_demon_lord")
            assert(boss.inventory[5] and boss.inventory[5].id == "armor_hollow_crown", "the boss relic is centered")
            assert(boss.inventory[5].traits[1] == "trait_hollow_crown", "carrying the boss's rule")
        end,
    },
    {
        name = "the innate trait attaches (and fires) through the relic, not a character property",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { { char = Character.instantiate("character_knight"), x = 1, y = 1 } },
                { { char = Character.instantiate("character_bandit"), x = 4, y = 4 } })
            local u = c.units[1]
            assert(Trait.has(u, "trait_oathward"), "the unit has Oathward, delivered by the grid relic")
            local from
            for _, t in ipairs(u.traits) do if t.id == "trait_oathward" then from = t end end
            assert(from and from.item and from.item.id == "armor_sworn_aegis",
                "the trait instance knows it came from the signature item")
            -- Oathward's onCombatStart set the guard: the whole path (item -> trait -> hook) ran.
            assert(u.guard and u.guard.kind == "oathward", "the opener fired and set the guard")
        end,
    },
    {
        name = "a signature relic is unsellable and unstealable, whatever it carries",
        fn = function()
            local relic = Item.instantiate("armor_sworn_aegis")
            assert(Vendor.sellValue(relic) == 0, "a bound relic is never worth anything to a vendor")
            -- Combat theft skips it: build a victim carrying only the relic and confirm nothing is taken.
            local c = Combat.new(arena(6, 6),
                { { char = Character.instantiate("character_bandit"), x = 1, y = 1 } },
                { { char = Character.instantiate("character_general_wrath"), x = 2, y = 1 } })
            local victim = c.units[2]
            -- Leave ONLY the bound relic on the victim, so a successful steal is impossible if it's honored.
            for i = 1, 9 do
                local it = victim.char.inventory[i]
                if it and it.id ~= "utility_unappeased_heart" then victim.char.inventory[i] = nil end
            end
            local taken = Combat.steal(c, c.units[1], victim)
            assert(taken == nil, "the boss's bound relic can't be pickpocketed, got " .. tostring(taken and taken.id))
            assert(victim.char.inventory[5] and victim.char.inventory[5].id == "utility_unappeased_heart",
                "and it stays in her grid")
        end,
    },
    {
        name = "a signature relic is forgeable in place and stays bound at its new level",
        fn = function()
            local player = Player.new()
            player.gold = 1000
            player.materials = { material_iron_scrap = 10, material_steel_ingot = 10, material_mythril = 10 }
            local relic = Item.instantiate("armor_sworn_aegis")
            assert(Item.isUpgradable(relic), "the relic has a stat to scale")
            assert(Blacksmith.canForge(relic), "and is forged at the blacksmith")

            local up = Blacksmith.upgrade(player, relic)
            assert(up and up.level == 1, "the forge returns a +1 instance")
            assert(Item.isBound(up), "the forged relic is still bound")
            assert(up.traits[1] == "trait_oathward", "and still carries its trait")
            local curve = Item.defs.armor_sworn_aegis.bonus.defense
            assert(up.bonus.defense == curve[2], "+1 defense is the level-1 entry")
        end,
    },
    {
        name = "the relic round-trips through a save at its cell and level, and re-seeds for an old save",
        fn = function()
            local player = Player.new()
            -- knight is roster[1]; upgrade its centered relic in place to +2.
            player.roster[1].inventory[5] = Item.instantiate("armor_sworn_aegis", 1, 2)

            local restored = Save.restore(Save.snapshot(player))
            local relic = restored.roster[1].inventory[5]
            assert(relic and relic.id == "armor_sworn_aegis", "the relic round-trips in the center cell")
            assert(relic.level == 2, "at its forged level, got " .. tostring(relic.level))
            assert(Item.isBound(relic), "and still bound")

            -- An old save whose grid predates the relic (center cell empty) gets it re-seeded at base.
            local snap = Save.snapshot(player)
            snap.roster[1].inventory[5] = nil
            local restored2 = Save.restore(snap)
            local reseeded = restored2.roster[1].inventory[5]
            assert(reseeded and reseeded.id == "armor_sworn_aegis", "a save without the relic gets it restored")
            assert(reseeded.level == 0, "re-seeded at base level")
        end,
    },
}
