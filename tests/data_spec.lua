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
            -- The company is earned through play, so the default is lean: just Rowan (the generic
            -- Mage/Archer/Priest were retired from the roster -- see data/player.lua).
            assert(#p.roster == 1, "roster should have 1 member (Rowan)")
            assert(p.roster[1].id == "character_rowan", "the lone default is Rowan")
            assert(next(p.completedQuests) == nil, "a new player has completed no quests (and so stands at every shop's opening stock)")
        end,
    },
    {
        -- The roster IS the company: there is no second list to fall out of step with it, and no cap
        -- to be turned away by. A recruit marches by virtue of being owned.
        name = "the roster is the whole marching company",
        fn = function()
            local p = Player.new()
            assert(p.party == nil, "there is no separate marching-company list")
            for i = 1, 12 do
                assert(Player.recruit(p, "character_saber") or i > 1,
                    "the first recruit joins; the rest are refused as duplicates")
            end
            assert(#p.roster == 2, "a duplicate is refused, but nothing else caps the roster")
            -- Everyone owned is handed to the battle as the company (states/game.lua), so the only
            -- number left about the board is how many of them may stand on it.
            assert(Player.MAX_PARTY == nil, "the company cap is gone")
            assert(Player.MAX_FIELD == 4, "the field cap is what remains")
        end,
    },
    {
        -- A new game opens the deployment phase with somebody already standing rather than an empty
        -- board, which is what lastDeployed is for.
        name = "a new player's starting roster counts as last battle's field",
        fn = function()
            local p = Player.new()
            assert(#p.lastDeployed == #p.roster, "every starting member is pre-selected")
            assert(Player.wasDeployed(p, p.roster[1]), "the lone default opens the phase placed")
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
        -- THE GATE THAT MAKES THE ACCURACY DEFAULT A SAFETY NET RATHER THAN A SHORTCUT.
        --
        -- Character.ACCURACY_STATS fills in skill/luck for a blueprint that declares neither, so a new
        -- character file loads and fights instead of erroring mid-battle. That convenience is also the
        -- failure mode: left unchecked, a body added next month quietly ships at 4/4 and reads as
        -- "average at everything" rather than as anything. Since hit chance is derived from these two,
        -- an unauthored body is not merely undescribed -- it is mechanically interchangeable with every
        -- other unauthored body.
        --
        -- So the default exists and nobody is allowed to keep it. Asked of the BLUEPRINT rather than an
        -- instance, because Character.instantiate is what applies the fallback and would answer 4 for
        -- everything either way.
        --
        -- Exempt: a body that never fights. `tier = 0` is the declared "not on the ladder" label
        -- (docs/bestiary.md) -- a prop, an escortee, a Wild Shape form -- and a blueprint with no stats
        -- of its own is a derived one (character_saber_bout shallow-copies its base and inherits both).
        name = "every combatant blueprint authors its own skill and luck",
        fn = function()
            local missing = {}
            for id, def in pairs(Character.defs) do
                local stats = def.stats
                if stats and (def.tier or 0) > 0 then
                    if stats.skill == nil or stats.luck == nil then
                        missing[#missing + 1] = id
                    end
                end
            end
            table.sort(missing)
            assert(#missing == 0,
                #missing .. " blueprint(s) still sit on the accuracy default and need real numbers "
                    .. "(run `. accuracy-author`): " .. table.concat(missing, ", "))
        end,
    },
    {
        -- The band the two stats are authored on, and the reason it is 0-10 rather than Fire Emblem's
        -- 0-20: they are added to and subtracted from `speed` (0-9) and sit beside `defense` (3-6), so
        -- a stat an order of magnitude larger than its neighbours would dominate every exchange it
        -- appeared in. A value outside the band is an authoring slip rather than a design choice -- and
        -- it would be invisible, because hit% clamps to 0..100 and simply swallows the overflow.
        name = "skill and luck stay inside the 0-10 band",
        fn = function()
            for id, def in pairs(Character.defs) do
                for _, key in ipairs({ "skill", "luck" }) do
                    local v = def.stats and def.stats[key]
                    if v ~= nil then
                        assert(type(v) == "number" and v >= 0 and v <= 10,
                            id .. " has " .. key .. " = " .. tostring(v) .. ", outside the 0-10 band")
                    end
                end
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
        name = "company vision is one step, and nothing widens it",
        fn = function()
            -- THIS CASE ASSERTED THE OPPOSITE, and the inversion is the change rather than a slip. It
            -- read "company vision radius is driven by a torch-carrying member": the base was 2, the
            -- best `visionRadius` in the company's packs was taken over it, and Gyeom's Ledger added
            -- one on top, so a kitted party saw four.
            --
            -- That was a radius over a TILE board, where the fog hid the shape of the country and three
            -- tiles of trail was a neighbourhood. A cell is a PLACE now (models/overworld.lua): one step
            -- is four places, four steps is most of a floor, and what the fog hides is no longer where
            -- the places are but what is standing in them -- which is the one thing that has to be found
            -- by going. So sight is flat at one and nothing raises it (models/player.lua's
            -- Player.VISION).
            local p = Player.new()
            assert(Player.visionRadius(p) == 1, "a company sees one step")

            -- The knight still starts with a torch, and it changes nothing.
            local hasTorch = false
            for _, char in ipairs(p.roster) do
                for _, item in ipairs(char.inventory or {}) do
                    if item.visionRadius then hasTorch = true end
                end
            end
            assert(hasTorch, "the opening company still carries the item this rule used to read")
            assert(Player.visionRadius(p) == 1, "a torch does not widen sight any more")

            for _, char in ipairs(p.roster) do char.inventory = {} end
            assert(Player.visionRadius(p) == 1, "and neither does carrying nothing")
            assert(Player.visionRadius(nil) == 1, "nil player (dev/test launch) sees the same")
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
