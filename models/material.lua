-- Materials: the raw stock spent at the Forge to upgrade gear. Unlike items, a material is not
-- carried in a character's 3x3 grid -- it is a plain resource the player accrues (player.materials =
-- { [id] = count }) and the forge consumes. Blueprints live in data/materials/<id>.lua (name,
-- description, sprite, tier, and -- for a house stock -- class). Pure logic (only the tolerant Sprite
-- loader), headless-safe.
--
-- TWO FAMILIES, because a material has exactly two jobs and one table cannot do both:
--
--   CRAFT STOCK   iron scrap / steel ingot / mythril -- the volume. Which grade an item draws on is
--                 the ITEM's own quality (its price), not how deep the forge rung is. A mythril
--                 sword needs mythril from its very first rung; a rusted knife never needs any.
--   HOUSE STOCK   one per class/sin -- the gate. Which house's stock an item wants is the item's
--                 `class`, and where it drops is the sponsoring house of the quest you ran, so
--                 running one line stocks another line's bench (see Overworld:placeCaches).
--
-- This replaces the older Material.TIER_BY_LEVEL, which graded by forge DEPTH -- "mythril means you
-- are deep in the ladder", which the ladder already said. See docs/progression.md.

local Registry = require("models.registry")

local Material = {}

Material.defs = Registry.load("data/materials", "data.materials")

function Material.get(id)
    return Material.defs[id]
end

-- ---------------------------------------------------------------------------
-- Craft stock: grade by the item's own quality
-- ---------------------------------------------------------------------------

-- Price bands cut TWO RUNGS OF THE SHELF APIECE. A price is derived from the slot it unlocks from now
-- (docs/shelf.md's grade -> slot -> price), so the six rungs of a house's shelf are six prices --
-- 80, 210, 345, 475, 610, 740 -- and a band is a pair of them: scrap for the opening rungs, steel for
-- the middle, mythril for the deep cut. Ascending; the first band the price fits in wins, and the last
-- entry is the open-ended top.
--
-- THEY WERE 249 AND 399, MEASURED AGAINST A SPREAD THAT NO LONGER EXISTS -- "474 priced items: p25 220,
-- median 320, p75 400", which is the hand-authored price list from before the grader, and gave roughly
-- a quarter scrap, half steel, a quarter mythril. Against the derived ladder those same two numbers put
-- rungs 0-1 on scrap, rung 2 ALONE on steel, and rungs 3, 4 and 5 all on mythril: 37% of the catalogue
-- on scrap, 18% on steel and 45% on the rarest ore, with the middle of every shelf forging out of the
-- top of the economy. Nobody decided that -- a table of absolute gold thresholds simply sat still while
-- the ladder underneath it was re-cut from twelve rungs to six.
--
-- Even thirds rather than the old quarter/half/quarter, and the change is honest rather than a
-- retuning: the grader spreads a house's stock evenly across its rungs, so with six of them a band is
-- worth two rungs or it is worth three, and there is no cut that makes the middle twice the ends.
--
-- A consumable is priced at 0.4 of its rung (Grade.PRICE_TYPE), so the whole of that shelf lands in the
-- bottom two bands and nothing one-shot ever bills mythril. That is not an oversight of this table: a
-- draught is cheap for being spent, and the rarest ore is for the thing you keep.
Material.GRADE_BY_PRICE = {
    { max = 249, id = "material_iron_scrap" },  -- rungs 0-1 (80, 210), and every consumable to rung 4
    { max = 549, id = "material_steel_ingot" }, -- rungs 2-3 (345, 475)
    { id = "material_mythril" },                -- rungs 4-5 (610, 740)
}

-- The craft stock `item` is forged from. An item with no price (a quest grant, a natural weapon) is
-- the cheapest grade rather than nil -- every forgeable thing must bill something.
function Material.gradeFor(item)
    local price = (item and item.price) or 0
    for _, band in ipairs(Material.GRADE_BY_PRICE) do
        if not band.max or price <= band.max then return band.id end
    end
    return Material.GRADE_BY_PRICE[#Material.GRADE_BY_PRICE].id
end

-- The craft stock in ascending grade, for anything picking "a better one" with no price to read --
-- an overworld cache grades its payload by how far off the critical path it sits, not by what it is
-- for. Same order as GRADE_BY_PRICE, so the two never disagree about which grade is richer.
function Material.craftGrades()
    local out = {}
    for _, band in ipairs(Material.GRADE_BY_PRICE) do out[#out + 1] = band.id end
    return out
end

-- ---------------------------------------------------------------------------
-- House stock: one per class
-- ---------------------------------------------------------------------------

-- class -> material id, built once by reverse-indexing the blueprints that declare a `class`. Data
-- defined rather than a table here, so adding a house means adding one file. A class with no house
-- stock authored yields nil, and the forge simply bills no house material for it.
local houseByClass
local function houseIndex()
    if not houseByClass then
        houseByClass = {}
        for id, def in pairs(Material.defs) do
            if def.class then houseByClass[def.class] = id end
        end
    end
    return houseByClass
end

function Material.houseFor(class)
    if not class then return nil end
    return houseIndex()[class]
end

-- Is `id` a house stock (as opposed to craft stock)? The forge detail pane reads this to say where a
-- material comes from without hardcoding the seven ids.
function Material.isHouse(id)
    local def = Material.defs[id]
    return def ~= nil and def.class ~= nil
end

-- Ordered list for any UI that enumerates materials: craft stock first by grade, then the houses by
-- name, so the two families never interleave.
function Material.list()
    local list = {}
    for id, def in pairs(Material.defs) do
        list[#list + 1] = {
            id = id,
            name = def.name,
            description = def.description,
            tier = def.tier or 1,
            class = def.class,
        }
    end
    table.sort(list, function(a, b)
        if (a.class ~= nil) ~= (b.class ~= nil) then return b.class ~= nil end
        if not a.class and a.tier ~= b.tier then return a.tier < b.tier end
        return a.name < b.name
    end)
    return list
end

return Material
