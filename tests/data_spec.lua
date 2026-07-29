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
            -- The party is earned through play, so the default is lean: just Rowan (the generic
            -- Mage/Archer/Priest were retired from the roster -- see data/player.lua).
            assert(#p.roster == 1, "roster should have 1 member (Rowan)")
            assert(#p.party == 1, "party should have 1 member (Rowan)")
            assert(p.roster[1].id == "character_rowan", "the lone default is Rowan")
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
            -- The lean default starts with one member; fill the party to the cap first.
            while #p.party < Player.MAX_PARTY do
                assert(Player.addToParty(p, Character.instantiate("character_rowan")),
                    "adding within the cap should succeed")
            end
            assert(#p.party == Player.MAX_PARTY, "party should reach the cap")
            local extra = Character.instantiate("character_rowan")
            assert(Player.addToParty(p, extra) == false, "adding past the cap must be rejected")
            assert(#p.party == Player.MAX_PARTY, "party must not grow past the cap")
        end,
    },
    {
        name = "removeFromParty frees a slot without touching the roster",
        fn = function()
            local p = Player.new()
            local rosterBefore, partyBefore = #p.roster, #p.party
            local member = p.party[1]
            assert(Player.removeFromParty(p, member), "member should be removed")
            assert(#p.party == partyBefore - 1, "party should have one fewer member")
            assert(#p.roster == rosterBefore, "roster is unchanged by party removal")
            assert(Player.addToParty(p, member), "a freed slot accepts a new member")
        end,
    },
    {
        -- The claim here is about SHAPE: a resource stat arrives as a { max, current } pair opened
        -- at full. The knight's actual numbers are a balance decision, so they are read off the
        -- blueprint rather than baked in -- a rebalance must never turn this red.
        name = "resource stats split into { max, current }",
        fn = function()
            local def = Character.defs.character_rowan.stats
            local c = Character.instantiate("character_rowan")
            for _, stat in ipairs({ "health", "mana", "stamina" }) do
                assert(type(c.stats[stat]) == "table", stat .. " should split into a table")
                assert(c.stats[stat].max == def[stat], stat .. " max should come from the blueprint")
                assert(c.stats[stat].current == def[stat], stat .. " should open at full")
            end
        end,
    },
    {
        -- Likewise: a flat stat stays the plain number the blueprint wrote, whatever that number is.
        name = "flat stats stay plain numbers",
        fn = function()
            local def = Character.defs.character_rowan.stats
            local c = Character.instantiate("character_rowan")
            for _, stat in ipairs({ "damage", "magicDamage", "defense", "magicDefense" }) do
                assert(type(c.stats[stat]) == "number", stat .. " should stay a plain number")
                assert(c.stats[stat] == def[stat], stat .. " should match the blueprint")
            end
        end,
    },
    {
        name = "starting inventory built from def item ids",
        fn = function()
            local c = Character.instantiate("character_rowan")
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
            local c = Character.instantiate("character_rowan")
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
            assert(Item.defs.consumable_fire_stone, "fire_stone missing")
            assert(Item.defs.ability_rain_of_arrows, "rain_of_arrows missing")
            -- The aura block (a top-level item field) survives instantiation.
            local stone = Item.instantiate("consumable_fire_stone")
            assert(stone.aura and stone.aura.grantTags[1] == "fire", "fire_stone carries its aura")
            -- Ability-level adjacency fields (inside activeAbility) survive too.
            local rain = Item.instantiate("ability_rain_of_arrows")
            assert(rain.activeAbility.requiresAdjacent.tag == "bow", "rain of arrows keeps requiresAdjacent")
        end,
    },
    {
        name = "addItem fills the first empty grid cell and leaves later gaps intact",
        fn = function()
            local c = Character.instantiate("character_rowan")
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
            -- Compare the blueprint against itself across the mutation, not against a literal: what
            -- is being asserted is that nothing CHANGED, which is true at any balance number.
            local before = Character.defs.character_rowan.stats.health
            local c = Character.instantiate("character_rowan")
            c.stats.health.current = 1
            assert(Character.defs.character_rowan.stats.health == before, "blueprint health mutated")
            assert(type(Character.defs.character_rowan.stats.health) == "number", "blueprint stat became a table")
        end,
    },
}
