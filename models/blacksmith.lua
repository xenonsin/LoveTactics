-- Blacksmith: the forge that levels up weapons and armor. Upgrading raises an item's `level`, which
-- Item.instantiate bakes into its scaling stat (a weapon's Power, an armor's defense) and its " +n"
-- name. An upgrade costs gold plus a material of the tier that level draws on (models/material.lua);
-- an ability item is NOT forged here -- it is upgraded at its class vendor instead (see the split in
-- ui/panels/vendor.lua). Pure logic, headless-safe: the panel (ui/panels/blacksmith.lua) drives it.

local Item = require("models.item")
local Material = require("models.material")
local Player = require("models.player")

local Blacksmith = {}

-- Is this item forgeable at the smithy? Weapons and armor only -- abilities go to the class vendor.
function Blacksmith.canForge(item)
    return Item.isUpgradable(item) and (item.type == "weapon" or item.type == "armor")
end

-- The cost to take `item` from its current level to the next: gold that climbs with the level, plus
-- a count of the material tier that level draws on. Returns nil once the item is at Item.MAX_LEVEL.
--   { level = <target>, gold = <n>, materials = { [id] = count } }
function Blacksmith.upgradeCost(item)
    local target = (item.level or 0) + 1
    if target > Item.MAX_LEVEL then return nil end
    local matId = Material.forLevel(target)
    return {
        level = target,
        gold = 40 * target,           -- +1 costs 40g, +5 costs 200g
        materials = { [matId] = target + 1 }, -- +1 costs 2, ramping to +5 costs 6
    }
end

-- Perform an upgrade on `item` owned by `player`: verify gold + materials, spend them, and return a
-- FRESH instance at the new level (the caller swaps it into the grid/stash it came from -- baking a
-- clean instance from the blueprint is why the level math never double-applies). Returns the new
-- item, or nil + a reason ("not forgeable" | "max level" | "gold" | "materials").
function Blacksmith.upgrade(player, item)
    if not Blacksmith.canForge(item) then return nil, "not forgeable" end
    local cost = Blacksmith.upgradeCost(item)
    if not cost then return nil, "max level" end
    if player.gold < cost.gold then return nil, "gold" end
    if not Player.canAffordMaterials(player, cost.materials) then return nil, "materials" end

    Player.spendGold(player, cost.gold)
    Player.spendMaterials(player, cost.materials)
    return Item.instantiate(item.id, item.quantity, cost.level)
end

return Blacksmith
