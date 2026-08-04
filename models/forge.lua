-- The Forge: the one bench in the city that raises an item's `level`. Upgrading bakes into the item's
-- scaling magnitudes and its " +n" name (Item.instantiate). Vendors SELL; the Forge UPGRADES -- one
-- bill, one ladder, one place to look. Pure logic, headless-safe: ui/panels/forge.lua drives it.
--
-- THREE KINDS OF WORK, all raising the same level:
--   gear       weapon / armor / utility, per instance -- you own one and hammer it
--   ability    per instance too. Was the class vendor's Upgrade tab; the bill and gate came here.
--   recipe     consumables, per TYPE -- refine the recipe (Player.recipeLevel) and every copy bought
--              thereafter comes at that tier. Was Vendor.upgradeRecipe.
--
-- THE BILL is three tracks (see models/material.lua for the two material families):
--   gold OR        climbs with the target level -- what PLAIN stock is forged with
--   technique      what DISCIPLINE stock is forged with instead: the currency a character banks by
--                  playing that discipline (models/discipline.lua). Never both; the two are
--                  alternatives on one track, not a surcharge.
--   craft stock    the grade the ITEM's own quality draws on, times a count that climbs
--   house stock    the item's class's material -- and for a DISCIPLINE item, every parent class's
--                  material at double the rate. That is the discipline gate: the deep cut of the shelf
--                  costs stock from both lines it descends from, so you must have run them.
--
-- WHY DISCIPLINE GEAR STOPPED COSTING GOLD. It used to cost gold like everything else and be held back
-- by a CEILING of `Discipline.level + 2` -- so a quest spent playing a ninja bought, eventually and
-- invisibly, the right to pay the same gold a knight pays for a knight thing. That is a permission
-- slip, not a reward, and permission slips are not felt. Billing the play itself makes the loop close
-- where the player can see it: fight as a ninja, bank ninja technique, forge the ninja kit. It is the
-- same conversion this bill already made once for the multiclass gate -- expressed as a price rather
-- than a lock -- applied to the last lock that was standing.
--
-- THE CEILING is keyed on the item, not on where you stand (the old Vendor.abilityLevelCap gated by
-- whichever shop happened to be open). See Forge.ceilingFor.

local Discipline = require("models.discipline")
local Item = require("models.item")
local Material = require("models.material")
local Player = require("models.player")
local Quest = require("models.quest")
local Vendor = require("models.vendor")

local Forge = {}

Forge.GOLD_PER_LEVEL = 40

-- Is this item worked at the bench per INSTANCE? Weapons, armor, utility gear and abilities all are.
-- Consumables are not: they refine per-type through Forge.recipeCost/refineRecipe instead, because a
-- stack of five potions is not five things to hammer. A bound signature relic IS one of these ordinary
-- types, so it forges in place like any gear -- `bound` blocks moving and selling it, never upgrading
-- it, which is the whole point of a build-around.
function Forge.canWork(item)
    if not item or not Item.isUpgradable(item) then return false end
    return item.type == "weapon" or item.type == "armor"
        or item.type == "utility" or item.type == "ability"
end

-- ---------------------------------------------------------------------------
-- The ceiling
-- ---------------------------------------------------------------------------

-- How far `player` may take `item` up the ladder right now. Three rules, in order of how specific the
-- item is about where it came from:
--
--   discipline item   NO ceiling. It used to be `Discipline.level + 2`; the technique price replaced
--                     it, and keeping both would be charging twice for the same permission -- you
--                     cannot buy a rung you have not played for, because the currency IS the playing.
--                     A brake the player watches fill beats a lock that silently opens.
--   class item        the standing of the house that sells it -- Quest.sponsorProgress through
--                     Vendor.tier, the same ladder its shelf opens on.
--   classless         no ceiling. Nothing gates it but the materials.
--
-- The discipline branch is FIRST and explicit, not a fall-through: discipline stock carries a `class`
-- too (a Ninja blade is rogue stock), so letting it drop into the branch below would quietly reinstate
-- a vendor-tier ceiling on top of the price.
--
-- Returns Item.MAX_LEVEL at most, always.
function Forge.ceilingFor(player, item)
    if not item then return 0 end
    if item.discipline and Discipline.defs[item.discipline] then
        return Item.MAX_LEVEL
    end
    local class = Item.classOf(item)
    if class then
        local vendorId = Forge.houseVendorFor(class)
        local done = vendorId and Quest.sponsorProgress(player, vendorId) or 0
        return math.min(Item.MAX_LEVEL, Vendor.tier(done) + 1)
    end
    return Item.MAX_LEVEL
end

-- The vendor id of the house that sells `class`, or nil. Kept as a name the Forge's own call sites read
-- naturally; the index itself moved to Vendor.forClass, which is the one owner of the class -> house
-- mapping now that the shop asks the same question.
function Forge.houseVendorFor(class)
    return Vendor.forClass(class)
end

-- ---------------------------------------------------------------------------
-- The bill
-- ---------------------------------------------------------------------------

-- The material half of a bill for taking something of quality `price`, class `class` and discipline
-- `discipline` up to `target`. Split out because a recipe bills off a blueprint and an instance bills
-- off an item, but both pay the same three tracks.
local function materialsFor(target, price, class, discipline)
    local materials = {}
    local function add(id, n)
        if id then materials[id] = (materials[id] or 0) + n end
    end

    -- Craft stock: the grade is the item's own quality, the count is the depth.
    add(Material.gradeFor({ price = price }), target + 1)

    -- House stock. A discipline item pays EVERY parent house at double the plain rate -- both lines,
    -- steeply, which is what makes the deep cut something you had to go and earn.
    if discipline and Discipline.defs[discipline] then
        for _, parent in ipairs(Discipline.parents(discipline)) do
            add(Material.houseFor(parent), target)
        end
    elseif class then
        add(Material.houseFor(class), math.ceil(target / 2))
    end

    return materials
end

-- The currency half of a bill -- gold for plain stock, technique for discipline stock, never both.
-- Returns the whole set the panel needs to draw the row and say who would pay it:
--   gold, technique, techniqueId, techniqueHolder, techniqueHeld
local function currencyFor(player, target, discipline)
    if discipline and Discipline.defs[discipline] then
        local holder, held = Discipline.techniqueHolder(player, discipline)
        return 0, Discipline.techniqueCost(target), discipline, holder, held
    end
    return Forge.GOLD_PER_LEVEL * target, 0, nil, nil, 0
end

-- The cost to take `item` one level, for `player`. Returns nil once the item is at Item.MAX_LEVEL.
--   { level, gold, technique, techniqueId, techniqueHolder, techniqueHeld,
--     materials = { [id] = count }, locked, ceiling }
-- `locked` means the target is past the ceiling this player has earned -- the bill is still shown, so
-- the panel can say what it would cost and why it cannot be paid yet. A discipline item is never
-- `locked` (it has no ceiling); what stops it is simply not holding the technique, which is an
-- affordability failure like any other and reads as one.
function Forge.upgradeCost(player, item)
    local target = (item.level or 0) + 1
    if target > Item.MAX_LEVEL then return nil end
    local ceiling = Forge.ceilingFor(player, item)
    local gold, technique, techId, holder, held = currencyFor(player, target, item.discipline)
    return {
        level = target,
        gold = gold,
        technique = technique,
        techniqueId = techId,
        techniqueHolder = holder,
        techniqueHeld = held,
        materials = materialsFor(target, item.price, Item.classOf(item), item.discipline),
        locked = target > ceiling,
        ceiling = ceiling,
    }
end

-- Perform an upgrade on `item` owned by `player`: verify the bench, the ceiling, the gold and the
-- materials, spend them, and return a FRESH instance at the new level (the caller swaps it into the
-- grid or stash it came from -- baking a clean instance from the blueprint is why the level math never
-- double-applies). Returns the new item, or nil + a reason:
--   "not forgeable" | "max level" | "locked" | "gold" | "technique" | "materials"
function Forge.upgrade(player, item)
    if not Forge.canWork(item) then return nil, "not forgeable" end
    local cost = Forge.upgradeCost(player, item)
    if not cost then return nil, "max level" end
    if cost.locked then return nil, "locked" end
    if player.gold < cost.gold then return nil, "gold" end
    if cost.technique > 0 and cost.techniqueHeld < cost.technique then return nil, "technique" end
    if not Player.canAffordMaterials(player, cost.materials) then return nil, "materials" end

    Player.spendGold(player, cost.gold)
    -- Comes off ONE body -- the strongest holder, the same one the bill named. See
    -- Discipline.spendTechnique for why it is never pooled across the roster.
    if cost.technique > 0 then
        Discipline.spendTechnique(player, cost.techniqueId, cost.technique)
    end
    Player.spendMaterials(player, cost.materials)
    return Item.instantiate(item.id, item.quantity, cost.level)
end

-- ---------------------------------------------------------------------------
-- Consumable recipes (per type)
-- ---------------------------------------------------------------------------

-- Which consumables the bench refines: any upgradable one. Unlike the old vendor rule there is no
-- "whose house is this" check -- there is only one bench now, so the question does not arise.
function Forge.canRefine(item)
    return item ~= nil and item.type == "consumable" and Item.isUpgradable(item)
end

-- The cost to raise `itemId`'s recipe one tier for `player`. Same three tracks as an instance, billed
-- off the blueprint (a recipe has no instance to read a price from). Returns nil at Item.MAX_LEVEL.
function Forge.recipeCost(player, itemId)
    local def = Item.defs[itemId]
    if not def then return nil end
    local target = Player.recipeLevel(player, itemId) + 1
    if target > Item.MAX_LEVEL then return nil end
    local probe = { discipline = def.discipline, class = def.class, type = def.type }
    local ceiling = Forge.ceilingFor(player, probe)
    local gold, technique, techId, holder, held = currencyFor(player, target, def.discipline)
    return {
        level = target,
        gold = gold,
        technique = technique,
        techniqueId = techId,
        techniqueHolder = holder,
        techniqueHeld = held,
        materials = materialsFor(target, def.price, def.class, def.discipline),
        locked = target > ceiling,
        ceiling = ceiling,
    }
end

-- Refine the recipe for consumable `itemId` one tier: verify it refines here, that the tier is within
-- the ceiling, and that the currency and materials are there; spend them and bump Player.recipeLevel.
-- Returns the new tier, or nil + a reason ("not forgeable" | "max level" | "locked" | "gold" |
-- "technique" | "materials") -- the same reason set as Forge.upgrade, so the panel needs one
-- message table.
function Forge.refineRecipe(player, itemId)
    local def = Item.defs[itemId]
    -- A blueprint probe rather than a real instance: isUpgradable reads the blueprint off `id` anyway,
    -- so instantiating a potion just to ask whether it refines would be a wasted bake.
    if not (def and Forge.canRefine({ id = itemId, type = def.type })) then
        return nil, "not forgeable"
    end
    local cost = Forge.recipeCost(player, itemId)
    if not cost then return nil, "max level" end
    if cost.locked then return nil, "locked" end
    if player.gold < cost.gold then return nil, "gold" end
    if cost.technique > 0 and cost.techniqueHeld < cost.technique then return nil, "technique" end
    if not Player.canAffordMaterials(player, cost.materials) then return nil, "materials" end

    Player.spendGold(player, cost.gold)
    if cost.technique > 0 then
        Discipline.spendTechnique(player, cost.techniqueId, cost.technique)
    end
    Player.spendMaterials(player, cost.materials)
    Player.setRecipeLevel(player, itemId, cost.level)
    return cost.level
end

return Forge
