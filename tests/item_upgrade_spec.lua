-- Tests for item upgrade levels (models/item.lua) and the Forge's three benches: a +n weapon's ability
-- Power and a +n armor's defense scale with the level, the " +n" rides on the name, and the Forge
-- spends the right resources. The bill itself (which materials, how many) is tests/forge_spec.lua.
-- Headless.

local Item = require("models.item")
local Character = require("models.character")
local Player = require("models.player")
local Forge = require("models.forge")
local Discipline = require("models.discipline")
local Vendor = require("models.vendor")

-- Bank `amount` of `key` on the player's first roster body, and return what it now holds. The Forge
-- bills technique off a real character (Discipline.techniqueHolder), so a test that wants to pay for a
-- rung has to put it somewhere a body can carry it.
local function bank(player, key, amount)
    local char = player.roster[1]
    char.technique = { [key] = amount }
    char.techniqueSpent = {}
    return char
end

return {
    {
        name = "a +n weapon's Power resolves to that level's tuned value, and the name gains a suffix",
        fn = function()
            local curve = Item.defs.weapon_iron_sword.activeAbility.damage -- the per-level list, 0..MAX_LEVEL
            assert(type(curve) == "table", "iron_sword Power is authored as a per-level table")
            local base = Item.instantiate("weapon_iron_sword")            -- level 0
            local up3 = Item.instantiate("weapon_iron_sword", 1, 3)       -- +3
            assert(base.activeAbility.damage == curve[1], "level 0 resolves the first table entry")
            assert(up3.activeAbility.damage == curve[4], "+3 resolves the level-3 entry (index 4)")
            assert(up3.activeAbility.damage > base.activeAbility.damage, "and it is stronger than the base")
            assert(up3.name == base.name .. " +3", "the name carries the +3 suffix, got " .. up3.name)
            assert(base.name:find("+") == nil, "a base item has no suffix")
        end,
    },
    {
        -- The armor's growth axis is its Defense; its resists are IDENTITY, authored flat (see
        -- models/curve.lua's span rule -- a resist with four points of climb in it cannot move every
        -- level, and widening it to ten would stack a second mitigation curve on the defense beside it).
        name = "a +n armor's defense resolves to that level's tuned value, and its resists hold flat",
        fn = function()
            local dcurve = Item.defs.armor_chainmail.bonus.defense
            local up2 = Item.instantiate("armor_chainmail", 1, 2)
            local up10 = Item.instantiate("armor_chainmail", 1, 10)
            assert(up2.bonus.defense == dcurve[3], "+2 defense is the level-2 entry (index 3)")
            assert(type(Item.defs.armor_chainmail.resist.slash) == "number", "slash resist is a flat magnitude")
            assert(up10.resist.slash == up2.resist.slash, "so forging does not deepen it")
            assert(up2.bonus.movement == -1, "and neither does the movement penalty")
        end,
    },
    {
        name = "a shield's Defend brace-defense is tunable and scales with its upgrade level",
        fn = function()
            local curve = Item.defs.armor_buckler.waitBehavior.defense
            assert(type(curve) == "table", "the buckler's brace defense is authored as a per-level table")
            local base = Item.instantiate("armor_buckler")       -- level 0
            local up3 = Item.instantiate("armor_buckler", 1, 3)   -- +3
            assert(base.waitBehavior.defense == curve[1], "level 0 braces the first table entry")
            assert(up3.waitBehavior.defense == curve[4], "+3 braces the level-3 entry (index 4)")
            assert(up3.waitBehavior.defense > base.waitBehavior.defense, "a forged shield braces harder")
        end,
    },
    {
        name = "the level clamps to MAX_LEVEL (10) and a short table holds at its last entry",
        fn = function()
            assert(Item.MAX_LEVEL == 10, "the ceiling is ten")
            local curve = Item.defs.weapon_iron_sword.activeAbility.damage
            local maxed = Item.instantiate("weapon_iron_sword", 1, 99) -- asks past the ceiling
            assert(maxed.level == 10, "the level is clamped to MAX_LEVEL")
            assert(maxed.activeAbility.damage == curve[#curve], "and Power reads the final tuned entry")
        end,
    },
    {
        name = "primaryStat leads with the defining magnitude at the current level, with its label",
        fn = function()
            local v, label = Item.primaryStat(Item.instantiate("weapon_iron_sword", 1, 2))
            assert(label == "Damage" and v == Item.defs.weapon_iron_sword.activeAbility.damage[3],
                "a blade leads with its leveled Damage")
            local dv, dlabel = Item.primaryStat(Item.instantiate("armor_leather_armor"))
            assert(dlabel == "Defense" and dv == Item.defs.armor_leather_armor.bonus.defense[1],
                "armor leads with its defense")
        end,
    },
    {
        name = "Item.growth charts a weapon's Damage curve, with the right levels flagged as changed",
        fn = function()
            local curve = Item.defs.weapon_iron_sword.activeAbility.damage
            local g = Item.growth("weapon_iron_sword")
            assert(g and g.maxLevel == Item.MAX_LEVEL, "growth spans 0..MAX_LEVEL")
            assert(g.primaryLabel == "Damage", "the primary stat leads")
            local dmg
            for _, s in ipairs(g.stats) do if s.label == "Damage" then dmg = s end end
            assert(dmg and dmg.primary, "Damage is a charted, primary-flagged stat")
            for lvl = 0, Item.MAX_LEVEL do
                assert(dmg.values[lvl] == curve[lvl + 1], "value at level " .. lvl .. " matches the curve")
            end
            assert(dmg.min == curve[1] and dmg.max == curve[#curve], "min/max are the curve endpoints")
            -- The iron sword steps up every single level, so every level >= 1 is flagged changed.
            for lvl = 1, Item.MAX_LEVEL do
                assert(dmg.changed[lvl], "level " .. lvl .. " is a step up")
            end
            assert(g.footprint == nil, "a single-target strike lays no footprint")
        end,
    },
    {
        name = "Item.growth splits scaling stats from flat ones (a chainmail's movement penalty)",
        fn = function()
            local g = Item.growth("armor_chainmail")
            local labels = {}
            for _, s in ipairs(g.stats) do labels[s.label] = true end
            assert(labels["Defense"], "defense scales and is charted")
            assert(not labels["Movement"], "the flat movement penalty is NOT a scaling bar")
            assert(not labels["Resist slash"], "and neither is a resist, which no longer scales")
            local flat = {}
            for _, f in ipairs(g.flat) do flat[f.label] = f.value end
            assert(flat["Movement"] == -1, "the penalty lands in the flat list at its constant value")
            assert(flat["Resist slash"] == 3, "so does each resist, at the number the mail simply IS")
        end,
    },
    {
        name = "Item.growth surfaces a footprint that opens up (First Motion's line into a cone)",
        fn = function()
            local g = Item.growth("weapon_first_motion")
            assert(g.footprint, "an area weapon reports a footprint")
            -- Base is a line; the cone opens at +6 (data/items/weapon/weapon_first_motion.lua).
            assert(g.footprint.levels[0].shape == "line", "it starts as a line")
            assert(g.footprint.levels[Item.MAX_LEVEL].shape == "cone", "and ends a cone")
            local hasBase, hasCone = false, false
            for _, lvl in ipairs(g.footprint.changedAt) do
                if lvl == 0 then hasBase = true end
                if g.footprint.levels[lvl].shape == "cone" and not hasCone then hasCone = lvl end
            end
            assert(hasBase, "the base form is a filmstrip frame")
            assert(hasCone == 6, "the cone is flagged as a change at +6, got " .. tostring(hasCone))
            -- Damage still charts as a normal scaling stat alongside the footprint.
            local hasDamage = false
            for _, s in ipairs(g.stats) do if s.label == "Damage" then hasDamage = true end end
            assert(hasDamage, "Damage charts beside the footprint")
        end,
    },
    {
        -- One bench now: gear and abilities are both worked per INSTANCE. Only consumables are turned
        -- away, because they refine per-type through Forge.refineRecipe instead.
        name = "the Forge works gear and abilities per instance, and turns consumables away",
        fn = function()
            local spell = Item.instantiate("ability_fireball")
            assert(Item.isUpgradable(spell) and Forge.canWork(spell), "an ability is honed at the bench")
            assert(Forge.canWork(Item.instantiate("weapon_iron_sword")), "so is a weapon")
            local bomb = Item.instantiate("consumable_acid_bomb")
            assert(not Forge.canWork(bomb), "a consumable is not hammered per instance")
            assert(Forge.canRefine(bomb), "it refines per recipe instead")
        end,
    },
    {
        name = "the Forge spends technique + materials and returns a leveled instance",
        fn = function()
            local player = Player.new()
            player.gold = 1000
            local sword = Item.instantiate("weapon_iron_sword")

            local cost = Forge.upgradeCost(player, sword)
            for id, n in pairs(cost.materials) do player.materials[id] = n end
            local char = bank(player, cost.techniqueId, cost.technique)

            local up = Forge.upgrade(player, sword)
            assert(up and up.level == 1, "the forge returns a +1 instance")
            assert(player.gold == 1000, "a knight blade costs no gold -- it costs knight play")
            assert(Character.techniqueAvailable(char, cost.techniqueId) == 0, "the technique was spent")
            assert(char.technique[cost.techniqueId] == cost.technique,
                "off the spent ledger, leaving what was EARNED intact")
            for id, n in pairs(cost.materials) do
                assert((player.materials[id] or 0) == 0, "every material in the bill was spent (" .. id .. " x" .. n .. ")")
            end
        end,
    },
    {
        name = "the Forge refuses an upgrade the player can't pay for, charging nothing",
        fn = function()
            local player = Player.new()
            player.gold = 0
            player.materials = {}
            local sword = Item.instantiate("weapon_iron_sword")
            local up, reason = Forge.upgrade(player, sword)
            assert(up == nil and (reason == "technique" or reason == "materials"),
                "the forge refuses, got " .. tostring(reason))
            assert(player.gold == 0, "and charges nothing")
        end,
    },
    {
        -- The ceiling replaced the old per-vendor standing cap: an ability with a plain class is held
        -- by the standing of the house that sells it (Forge.ceilingFor), which at zero quests is +2.
        name = "the Forge hones an ability, and the house's standing caps how far",
        fn = function()
            local player = Player.new()
            player.gold = 1000
            local spell = Item.instantiate("ability_fireball") -- mage class -> arcanum
            local cost1 = Forge.upgradeCost(player, spell)
            assert(cost1 and not cost1.locked, "the first rung is open with no quests done")
            for id, n in pairs(cost1.materials) do player.materials[id] = n end
            local char = bank(player, cost1.techniqueId, cost1.technique)

            local up = Forge.upgrade(player, spell)
            assert(up and up.level == 1, "the forge returns a +1 spell")
            assert(cost1.techniqueId == "mage", "a fireball is honed by having cast as a mage")
            assert(Character.techniqueAvailable(char, "mage") == 0, "and the technique was spent")

            -- Past the ceiling the bill is still quoted, but the bench will not take it. The opening
            -- ceiling is Forge.CEILING_BASE, read rather than typed -- it used to be Vendor.tier(0)+1
            -- and moved when the bench started following the shelf one quest at a time.
            local hi = Item.instantiate("ability_fireball", 1, Forge.CEILING_BASE)
            local cost4 = Forge.upgradeCost(player, hi)
            assert(cost4 and cost4.locked, "one rung past the ceiling is refused with no quests done")
            assert(cost4.ceiling == Forge.CEILING_BASE,
                "which stands at +" .. Forge.CEILING_BASE .. ", got " .. tostring(cost4.ceiling))
            local up4, reason = Forge.upgrade(player, hi)
            assert(up4 == nil and reason == "locked", "and the forge refuses it, got " .. tostring(reason))
        end,
    },
    {
        name = "Vendor.priceFor scales +50% of base per tier; sellValue follows the item's level",
        fn = function()
            assert(Vendor.priceFor(100, 0) == 100, "tier 0 is the base price")
            assert(Vendor.priceFor(100, 1) == 150, "+1 is +50%")
            assert(Vendor.priceFor(100, 4) == 300, "+4 is triple the base")
            assert(Vendor.priceFor(nil, 3) == nil, "a never-sold item has no price at any tier")
            -- Sell value is half the leveled shelf price, so a refined consumable is worth more.
            local base = Item.instantiate("consumable_acid_bomb")      -- +0
            local up2 = Item.instantiate("consumable_acid_bomb", 1, 2) -- +2
            assert(Vendor.sellValue(up2) > Vendor.sellValue(base), "a +2 consumable sells for more than a +0")
            assert(Vendor.sellValue(up2) == math.floor(Vendor.priceFor(Item.defs.consumable_acid_bomb.price, 2) * 0.5),
                "sell value is half the leveled shelf price")
        end,
    },
    {
        -- The acid bomb is Bombardier stock, so it is billed in that discipline's TECHNIQUE rather than
        -- in gold (models/forge.lua) -- the recipe ladder is climbed by playing the discipline, not by
        -- shopping. The rest of the refinement contract is unchanged.
        name = "the Forge refines a consumable recipe per-type: paid once, every future buy upgraded",
        fn = function()
            local player = Player.new()
            player.gold = 1000
            assert(Player.recipeLevel(player, "consumable_acid_bomb") == 0, "the recipe starts at tier 0")

            local cost = Forge.recipeCost(player, "consumable_acid_bomb")
            assert(cost.technique > 0 and cost.gold == 0, "Bombardier stock is billed in technique")
            for id, n in pairs(cost.materials) do player.materials[id] = n end
            local char = bank(player, cost.techniqueId, cost.technique)

            local level = Forge.refineRecipe(player, "consumable_acid_bomb")
            assert(level == 1, "the recipe rises to +1, got " .. tostring(level))
            assert(Player.recipeLevel(player, "consumable_acid_bomb") == 1, "the tier is stored on the player")
            assert(player.gold == 1000, "no gold was spent on discipline stock")
            assert(Character.techniqueAvailable(char, cost.techniqueId) == 0,
                "the technique was spent instead")

            -- The shelf now lists acid_bomb at the raised tier and its scaled price. A purchase would
            -- instantiate at this level. Queried with a high quest count so its own gate is met.
            local found
            for _, e in ipairs(Vendor.stock("alchemist", 99, player.recipes)) do
                if e.id == "consumable_acid_bomb" then found = e end
            end
            assert(found and found.level == 1, "the shelf lists the refined tier")
            assert(found.price == Vendor.priceFor(Item.defs.consumable_acid_bomb.price, 1), "and at the scaled price")
        end,
    },
    {
        -- The acid bomb is Bombardier stock, and a discipline recipe now has NO ceiling: the technique
        -- price is the whole brake. What used to be a `locked` refusal at +3 is an affordability
        -- refusal, which is the point of the change -- a wall you can see the height of, and a bank you
        -- watch fill toward it, rather than a lock that opens silently somewhere off-screen.
        name = "recipe refinement is gated by banked technique, and refuses when unpaid",
        fn = function()
            local player = Player.new()
            player.gold = 5000
            player.materials = setmetatable({}, { __index = function() return 99 end })
            local disciplineId = Forge.recipeCost(player, "consumable_acid_bomb").techniqueId
            assert(disciplineId, "the acid bomb is discipline stock")

            -- Bank exactly enough for the first two rungs and not the third.
            local need = 0
            for tier = 1, 2 do need = need + Discipline.techniqueCost(tier) end
            local char = bank(player, disciplineId, need)

            assert(Forge.refineRecipe(player, "consumable_acid_bomb") == 1)
            assert(Forge.refineRecipe(player, "consumable_acid_bomb") == 2)
            assert(Character.techniqueAvailable(char, disciplineId) == 0, "both rungs came out of the bank")

            local up3, reason = Forge.refineRecipe(player, "consumable_acid_bomb")
            assert(up3 == nil and reason == "technique",
                "+3 is past what was banked, got " .. tostring(reason))
            assert(Player.recipeLevel(player, "consumable_acid_bomb") == 2, "and the tier held at +2")

            -- A PLAIN class recipe rides the same track now, billed to its own house instead of to a
            -- discipline -- so an empty ledger refuses it for the same reason and with the same word.
            local plain = Player.new()
            plain.gold = 0
            plain.materials = setmetatable({}, { __index = function() return 99 end })
            local plainId
            for id, def in pairs(Item.defs) do
                if def.type == "consumable" and def.price and not def.discipline and def.class
                    and Item.isUpgradable(Item.instantiate(id)) then
                    plainId = plainId or id
                end
            end
            if plainId then
                local poor, r = Forge.refineRecipe(plain, plainId)
                assert(poor == nil and r == "technique", "an empty ledger -> refused, got " .. tostring(r))
                assert(Player.recipeLevel(plain, plainId) == 0, "and nothing changed")
            end
        end,
    },
}
