-- Tests for the model/data layer: instantiation, resource-stat split,
-- inventory cap, registry discovery, and blueprint immutability.

local Player = require("models.player")
local Character = require("models.character")
local Item = require("models.item")
local Status = require("models.status")

return {
    {
        name = "player defaults come from data/player.lua",
        fn = function()
            local p = Player.new()
            assert(p.gold == Player.defaults.gold, "gold should come from the defaults")
            assert(p.prestige == Player.defaults.prestige, "prestige should come from the defaults")
            assert(#p.roster == 4, "roster should have 4 members")
            assert(#p.party == 4, "party should have 4 members")
            assert(next(p.reputation) == nil, "a new player owes nobody any reputation")
            assert(next(p.completedQuests) == nil, "a new player has completed no quests")
        end,
    },
    {
        name = "party members reference the same roster instances",
        fn = function()
            local p = Player.new()
            assert(p.party[1] == p.roster[1], "party[1] should be the roster[1] instance")
        end,
    },
    {
        name = "party is capped at Player.MAX_PARTY",
        fn = function()
            local p = Player.new()
            assert(#p.party == Player.MAX_PARTY, "party should start full at the cap")
            local extra = Character.instantiate("character_knight")
            assert(Player.addToParty(p, extra) == false, "adding past the cap must be rejected")
            assert(#p.party == Player.MAX_PARTY, "party must not grow past the cap")
        end,
    },
    {
        name = "removeFromParty frees a slot without touching the roster",
        fn = function()
            local p = Player.new()
            local member = p.party[1]
            assert(Player.removeFromParty(p, member), "member should be removed")
            assert(#p.party == Player.MAX_PARTY - 1, "party should have one fewer member")
            assert(#p.roster == 4, "roster is unchanged by party removal")
            assert(Player.addToParty(p, member), "a freed slot accepts a new member")
        end,
    },
    {
        name = "resource stats split into { max, current }",
        fn = function()
            local c = Character.instantiate("character_knight")
            assert(c.stats.health.max == 70 and c.stats.health.current == 70, "health")
            assert(c.stats.mana.max == 20, "mana max")
            assert(c.stats.stamina.current == 60, "stamina current")
        end,
    },
    {
        name = "flat stats stay plain numbers",
        fn = function()
            local c = Character.instantiate("character_knight")
            assert(type(c.stats.damage) == "number" and c.stats.damage == 14, "damage")
            assert(type(c.stats.magicDamage) == "number", "magicDamage")
            assert(type(c.stats.defense) == "number", "defense")
            assert(type(c.stats.magicDefense) == "number", "magicDefense")
        end,
    },
    {
        name = "starting inventory built from def item ids",
        fn = function()
            local c = Character.instantiate("character_knight")
            -- Iron Mace, Chainmail, Healing Potion, Torch, and the bound Sworn Aegis relic (cell 5),
            -- which carries both her guard and her unlock-gated signature answer.
            assert(#c.inventory == 5, "expected 5 starting items, got " .. #c.inventory)
            assert(c.inventory[1].name == "Iron Mace", "first item")
            assert(c.inventory[5].id == "armor_sworn_aegis", "the signature relic sits in the center")
        end,
    },
    {
        name = "inventory hard cap of 9 is enforced",
        fn = function()
            local c = Character.instantiate("character_knight")
            while #c.inventory < Character.MAX_INVENTORY do
                assert(Character.addItem(c, Item.instantiate("weapon_iron_sword")), "add under cap")
            end
            assert(#c.inventory == 9, "should be full at 9")
            assert(Character.addItem(c, Item.instantiate("weapon_iron_sword")) == false, "10th add rejected")
            assert(#c.inventory == 9, "must not grow past cap")
        end,
    },
    {
        name = "adjacency content (Burn status + the three items) loads via the registries",
        fn = function()
            assert(Status.defs.status_burn, "burn status missing")
            assert(Item.defs.ability_omnislash, "omnislash missing")
            assert(Item.defs.utility_fire_stone, "fire_stone missing")
            assert(Item.defs.ability_rain_of_arrows, "rain_of_arrows missing")
            -- The aura block (a top-level item field) survives instantiation.
            local stone = Item.instantiate("utility_fire_stone")
            assert(stone.aura and stone.aura.grantTags[1] == "fire", "fire_stone carries its aura")
            -- Ability-level adjacency fields (inside activeAbility) survive too.
            local rain = Item.instantiate("ability_rain_of_arrows")
            assert(rain.activeAbility.requiresAdjacent.tag == "bow", "rain of arrows keeps requiresAdjacent")
        end,
    },
    {
        name = "addItem fills the first empty grid cell and leaves later gaps intact",
        fn = function()
            local c = Character.instantiate("character_knight")
            c.inventory = {} -- start clean; this test controls the layout (3 dense items in slots 1..3)
            Character.addItem(c, Item.instantiate("weapon_iron_sword"))
            Character.addItem(c, Item.instantiate("armor_chainmail"))
            Character.addItem(c, Item.instantiate("consumable_healing_potion"))
            c.inventory[2] = nil -- open a gap in the middle
            assert(Character.itemCount(c) == 2, "two items remain after clearing slot 2")
            assert(Character.firstEmptySlot(c) == 2, "slot 2 is the first empty cell")
            Character.addItem(c, Item.instantiate("weapon_iron_bow"))
            assert(c.inventory[2] and c.inventory[2].name == "Iron Bow", "the new item fills the gap at slot 2")
            assert(c.inventory[3], "the item beyond the gap is untouched")
        end,
    },
    {
        name = "torch item carries its configurable visionRadius through instantiation",
        fn = function()
            local torch = Item.instantiate("utility_torch")
            assert(torch.visionRadius == Item.defs.utility_torch.visionRadius,
                "torch instance should carry the blueprint's visionRadius")
            local sword = Item.instantiate("weapon_iron_sword")
            assert(sword.visionRadius == nil, "a non-torch item has no visionRadius")
        end,
    },
    {
        name = "party vision radius is driven by a torch-carrying member",
        fn = function()
            local p = Player.new()
            -- The knight starts with a torch, so the party sees at the torch's radius.
            assert(Player.visionRadius(p) == Item.defs.utility_torch.visionRadius,
                "party with a torch should see at the torch's radius")

            -- With no torch anywhere, the party falls back to the base radius.
            for _, char in ipairs(p.party) do char.inventory = {} end
            assert(Player.visionRadius(p) == Player.BASE_VISION,
                "torchless party should see at BASE_VISION")

            -- A nil player (dev/test launch) also yields the base radius.
            assert(Player.visionRadius(nil) == Player.BASE_VISION, "nil player -> base vision")
        end,
    },
    {
        name = "registry auto-discovers item def files by filename",
        fn = function()
            assert(Item.defs.consumable_healing_potion, "healing_potion missing")
            assert(Item.defs.weapon_iron_sword, "iron_sword missing")
        end,
    },
    {
        name = "blueprints are untouched after instantiation",
        fn = function()
            local c = Character.instantiate("character_knight")
            c.stats.health.current = 1
            assert(Character.defs.character_knight.stats.health == 70, "blueprint health mutated")
            assert(type(Character.defs.character_knight.stats.health) == "number", "blueprint stat became a table")
        end,
    },
}
