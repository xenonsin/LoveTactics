-- Tests for the model/data layer: instantiation, resource-stat split,
-- inventory cap, registry discovery, and blueprint immutability.

local Player = require("models.player")
local Character = require("models.character")
local Item = require("models.item")

return {
    {
        name = "player defaults come from data/player.lua",
        fn = function()
            local p = Player.new()
            assert(p.gold == 0, "gold should be 0")
            assert(p.prestige == 1, "prestige should be 1")
            assert(#p.party == 1, "party should have 1 member")
        end,
    },
    {
        name = "resource stats split into { max, current }",
        fn = function()
            local c = Character.instantiate("knight")
            assert(c.stats.health.max == 100 and c.stats.health.current == 100, "health")
            assert(c.stats.mana.max == 20, "mana max")
            assert(c.stats.stamina.current == 60, "stamina current")
        end,
    },
    {
        name = "flat stats stay plain numbers",
        fn = function()
            local c = Character.instantiate("knight")
            assert(type(c.stats.damage) == "number" and c.stats.damage == 14, "damage")
            assert(type(c.stats.magicDamage) == "number", "magicDamage")
            assert(type(c.stats.defense) == "number", "defense")
            assert(type(c.stats.magicDefense) == "number", "magicDefense")
        end,
    },
    {
        name = "starting inventory built from def item ids",
        fn = function()
            local c = Character.instantiate("knight")
            assert(#c.inventory == 2, "expected 2 starting items, got " .. #c.inventory)
            assert(c.inventory[1].name == "Iron Sword", "first item")
        end,
    },
    {
        name = "inventory hard cap of 9 is enforced",
        fn = function()
            local c = Character.instantiate("knight")
            while #c.inventory < Character.MAX_INVENTORY do
                assert(Character.addItem(c, Item.instantiate("iron_sword")), "add under cap")
            end
            assert(#c.inventory == 9, "should be full at 9")
            assert(Character.addItem(c, Item.instantiate("iron_sword")) == false, "10th add rejected")
            assert(#c.inventory == 9, "must not grow past cap")
        end,
    },
    {
        name = "registry auto-discovers item def files by filename",
        fn = function()
            assert(Item.defs.healing_potion, "healing_potion missing")
            assert(Item.defs.iron_sword, "iron_sword missing")
        end,
    },
    {
        name = "blueprints are untouched after instantiation",
        fn = function()
            local c = Character.instantiate("knight")
            c.stats.health.current = 1
            assert(Character.defs.knight.stats.health == 100, "blueprint health mutated")
            assert(type(Character.defs.knight.stats.health) == "number", "blueprint stat became a table")
        end,
    },
}
