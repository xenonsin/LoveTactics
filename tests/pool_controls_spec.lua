-- THE FILTER AND THE SORT OVER A RACK OF TILES (ui/pool_controls.lua): the pure half of the pair the
-- vendor screen now carries. What is pinned here is the part that decides what a player SEES -- the
-- strip's AND/OR rule, the orders, and the promise that neither control writes anything.
--
-- Nothing here draws: the chrome needs a window and the view does not, which is the same split
-- tests/loadout_sort_spec.lua makes for the Armory's own copy. Panels are built straight through the
-- metatable with the two fields the view reads, since the constructor bakes fonts.
--
-- Items are fabricated plain tables (name, type, price only), so the cases say what they mean and
-- cannot drift when content is edited.

local PoolControls = require("ui.pool_controls")

local function controls(sorts, filters, sortIndex)
    return setmetatable({ sorts = sorts or PoolControls.SHELF_SORTS, filters = filters,
        sortIndex = sortIndex or 1 }, PoolControls)
end

local function sortIndexOf(sorts, id)
    for i, spec in ipairs(sorts) do
        if spec.id == id then return i end
    end
    error("no such order: " .. tostring(id))
end

local function names(rows)
    local out = {}
    for i, row in ipairs(rows) do out[i] = row.item.name end
    return table.concat(out, ",")
end

-- A rack deliberately jumbled against every axis: the cheapest is last, the alphabetical first is a
-- potion, and two share a type.
local function rack()
    return {
        { item = { name = "Iron Sword", type = "weapon", price = 40 } },
        { item = { name = "Elixir", type = "consumable", price = 25 } },
        { item = { name = "Chainmail", type = "armor", price = 120 } },
        { item = { name = "Carrion Axe", type = "weapon", price = 90 } },
    }
end

local function typeFilter(options)
    return { {
        label = "Type", options = options, selected = {},
        valueOf = function(item) return item and item.type end,
    } }
end

return {
    {
        -- THE DEFAULT ORDER IS THE LIST ITSELF, and it must stay the identity: a shelf deals its stock
        -- rung-first for a reason, and a control that re-ordered it merely by existing would change what
        -- every shop in the game looks like before the player has touched anything.
        name = "an untouched pair shows the rack exactly as it was handed over",
        fn = function()
            local rows = rack()
            local view = controls():apply(rows)
            assert(view == rows, "with nothing picked the same table comes back, not a copy")
            assert(names(view) == "Iron Sword,Elixir,Chainmail,Carrion Axe", "shelf order, untouched")
            assert(PoolControls.SHELF_SORTS[1].less == nil and PoolControls.STASH_SORTS[1].less == nil,
                "the first order in each list is the list's own and carries no comparator")
        end,
    },
    {
        -- WHAT IS ON THE TICKET. A shelf price is scaled to the item's recipe tier (Vendor.priceFor) and
        -- the blueprint's own `price` is not what the tile prints, so an order named Price that read the
        -- blueprint would sort a rack into an order the player cannot see.
        name = "Price sorts by the price the tile actually shows",
        fn = function()
            local rows = {
                { item = { name = "Dear", price = 10 }, entry = { price = 900 } },
                { item = { name = "Cheap", price = 800 }, entry = { price = 5 } },
            }
            local c = controls(PoolControls.SHELF_SORTS, nil, sortIndexOf(PoolControls.SHELF_SORTS, "price"))
            assert(names(c:apply(rows)) == "Cheap,Dear", "the ticket wins over the blueprint's worth")
            -- ...and a rack of bare items (no entry) still sorts, on the only price it has.
            local bare = { { item = { name = "B", price = 20 } }, { item = { name = "A", price = 10 } } }
            assert(names(c:apply(bare)) == "A,B", "a rack with no tickets falls back to the item's worth")
        end,
    },
    {
        name = "Name is A to Z and Type puts weapons first, potions last",
        fn = function()
            local byName = controls(PoolControls.SHELF_SORTS, nil,
                sortIndexOf(PoolControls.SHELF_SORTS, "name"))
            assert(names(byName:apply(rack())) == "Carrion Axe,Chainmail,Elixir,Iron Sword", "A to Z")

            local byType = controls(PoolControls.SHELF_SORTS, nil,
                sortIndexOf(PoolControls.SHELF_SORTS, "type"))
            -- Weapons, then armour, then the potion -- and alphabetical inside a type, which is what
            -- makes the order total rather than merely grouped.
            assert(names(byType:apply(rack())) == "Carrion Axe,Iron Sword,Chainmail,Elixir",
                "got " .. names(byType:apply(rack())))
        end,
    },
    {
        -- ARRIVAL ORDER IS THE TIE-BREAK, always. Every order here is a partial one (two weapons at the
        -- same price are equal to it), and table.sort on a comparator that calls two things equal is
        -- free to put them in either order -- which would make a rack shuffle between two frames.
        name = "ties keep the order they arrived in",
        fn = function()
            local rows = {
                { item = { name = "Same", type = "weapon", price = 10 } },
                { item = { name = "Same", type = "weapon", price = 10 } },
                { item = { name = "Same", type = "weapon", price = 10 } },
            }
            rows[1].tag, rows[2].tag, rows[3].tag = 1, 2, 3
            local c = controls(PoolControls.SHELF_SORTS, nil, sortIndexOf(PoolControls.SHELF_SORTS, "price"))
            local view = c:apply(rows)
            assert(view[1].tag == 1 and view[2].tag == 2 and view[3].tag == 3,
                "equal rows must come back in the order they were dealt")
        end,
    },
    {
        -- OR INSIDE A GROUP, AND ACROSS THEM. Two chips in one group is "either of these", which is the
        -- whole reason chips toggle rather than cycle; two groups is "both", which is what makes a
        -- second axis worth having at all.
        name = "chips are an OR within a group and an AND across groups",
        fn = function()
            local f = typeFilter({ "weapon", "armor", "consumable" })
            local c = controls(PoolControls.SHELF_SORTS, f)
            assert(names(c:apply(rack())) == "Iron Sword,Elixir,Chainmail,Carrion Axe",
                "a group with nothing picked narrows nothing")

            f[1].selected.weapon = true
            assert(names(c:apply(rack())) == "Iron Sword,Carrion Axe", "one chip keeps its own kind")
            f[1].selected.armor = true
            assert(names(c:apply(rack())) == "Iron Sword,Chainmail,Carrion Axe", "two chips keep both")

            -- A second group, ANDed: costly things that are also weapons.
            c.filters[2] = {
                label = "Price", options = { "dear" }, selected = { dear = true },
                valueOf = function(item) return (item.price or 0) >= 90 and "dear" or "cheap" end,
            }
            assert(names(c:apply(rack())) == "Chainmail,Carrion Axe",
                "an item must pass every group, not any of them")
        end,
    },
    {
        -- A VIEW IS NOT AN EDIT. Everything downstream of a rack -- the press that buys, the price on
        -- the tile, the stash index a sale writes back through -- holds the ROW, so the rows have to
        -- come back as themselves and the list behind them has to be left alone.
        name = "narrowing and reordering never touch the rack they are shown over",
        fn = function()
            local rows = rack()
            local first, third = rows[1], rows[3]
            local f = typeFilter({ "weapon", "armor", "consumable" })
            f[1].selected.weapon = true
            local c = controls(PoolControls.SHELF_SORTS, f, sortIndexOf(PoolControls.SHELF_SORTS, "name"))
            local view = c:apply(rows)

            assert(#rows == 4 and rows[1] == first and rows[3] == third, "the rack itself is untouched")
            assert(view ~= rows, "a narrowed view is a new list")
            assert(view[2] == first, "and it hands back the very rows it was given, not copies of them")
        end,
    },
    {
        -- A SELECTION OUTLIVES A REBUILD ONLY WHILE IT STILL MEANS SOMETHING. The shop rebuilds its rows
        -- after every transaction and re-offers the strip off the new stock, so a chip for a type the
        -- counter no longer carries would leave a lit Filter button over a rack nothing can fill and no
        -- chip on the strip to explain it.
        name = "a rebuilt strip keeps the picks it can still offer and forgets the rest",
        fn = function()
            local c = controls()
            local first = typeFilter({ "weapon", "armor" })
            first[1].selected.weapon = true
            first[1].selected.armor = true
            c:setFilters(first)
            assert(c:activeCount() == 2, "both picks stand")

            c:setFilters(typeFilter({ "armor", "consumable" })) -- the weapons sold out
            assert(c:activeCount() == 1 and c.filters[1].selected.armor,
                "the pick that is still on offer survives; the one that is gone goes with it")

            c:setFilters(nil)
            assert(c.filters == nil and not c:isNarrowed(), "a rack with nothing to filter offers no strip")
        end,
    },
}
