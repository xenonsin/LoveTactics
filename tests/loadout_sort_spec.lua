-- The Armory (Loadout) stash sort: the pure half of ui/panels/party.lua's "Sort" dropdown. Like the
-- filter strip beside it, an order is a VIEW -- the real player.stash is never reordered -- so the same
-- pool-index -> stash-index map has to carry every transfer back to the right owned item. This pins the
-- five orders, the map under each, and the tie rule, none of which touch love.graphics.
--
-- Items are fabricated plain tables (just the fields the comparators read: name, type, price) so the
-- test says what it means and can't drift when content is edited.

local Party = require("ui.panels.party")

-- A bare panel with just the fields visibleStash reads -- enough to call the pure logic without
-- building the whole love.graphics-bound screen (mirrors loadout_filter_spec's panel()).
local function panel(stash, sortId)
    local index = 1
    for i, spec in ipairs(Party.SORTS) do
        if spec.id == sortId then index = i break end
    end
    return setmetatable({ player = { stash = stash }, sortIndex = index }, Party)
end

local function names(view)
    local out = {}
    for i, item in ipairs(view) do out[i] = item.name end
    return table.concat(out, ",")
end

-- Arrival order is the stash's own order, so the fixture is deliberately jumbled against every
-- other axis: the newest item is cheap, the alphabetical first is last in, and two share a type.
local sword  = { name = "Iron Sword", type = "weapon", price = 40 }
local potion = { name = "Elixir", type = "consumable", price = 25 }
local mail   = { name = "Chainmail", type = "armor", price = 120 }
local axe    = { name = "Carrion Axe", type = "weapon", price = 90 }

local function fourItemStash()
    return { sword, potion, mail, axe }
end

return {
    {
        name = "the default order is the stash itself, with no map to keep",
        fn = function()
            local p = panel(fourItemStash(), "found")
            local view = p:visibleStash()
            assert(names(view) == "Iron Sword,Elixir,Chainmail,Carrion Axe", "arrival order, untouched")
            assert(p.stashMap == nil, "an unsorted, unfiltered stash needs no index map")
            assert(p:stashIndex(3) == 3, "the pool index IS the stash index when nothing reorders it")
        end,
    },
    {
        name = "Recent shows the newest arrival first and maps its cells back",
        fn = function()
            local p = panel(fourItemStash(), "recent")
            local view = p:visibleStash()
            assert(names(view) == "Carrion Axe,Chainmail,Elixir,Iron Sword", "last in, first shown")
            -- The axe is the fourth item the player owns; showing it first must not make it stash #1.
            assert(p:stashIndex(1) == 4 and p:stashIndex(4) == 1, "the map reverses with the view")
        end,
    },
    {
        name = "Type groups weapons first and potions last, alphabetical inside a type",
        fn = function()
            local p = panel(fourItemStash(), "type")
            assert(names(p:visibleStash()) == "Carrion Axe,Iron Sword,Chainmail,Elixir",
                "weapons (A-Z), then armor, then the consumable")
            assert(p:stashIndex(1) == 4, "the first cell is still the axe's real stash slot")
        end,
    },
    {
        name = "Name is A to Z and Value is costliest first",
        fn = function()
            assert(names(panel(fourItemStash(), "name"):visibleStash())
                == "Carrion Axe,Chainmail,Elixir,Iron Sword", "A to Z")
            assert(names(panel(fourItemStash(), "value"):visibleStash())
                == "Chainmail,Carrion Axe,Iron Sword,Elixir", "costliest first")
        end,
    },
    {
        name = "items an order cannot separate keep their arrival positions",
        fn = function()
            -- Two priceless items and one worth something: Value has nothing to say about the pair, so
            -- they must come out in the order the stash holds them rather than in whatever order
            -- table.sort happens to leave an unstable comparison in.
            local a = { name = "Keepsake", type = "utility" }
            local b = { name = "Charm", type = "utility" }
            local paid = { name = "Chainmail", type = "armor", price = 120 }
            local p = panel({ a, paid, b }, "value")
            assert(names(p:visibleStash()) == "Chainmail,Keepsake,Charm", "ties fall back to arrival order")
            assert(p:stashIndex(2) == 1 and p:stashIndex(3) == 3, "and the map follows them")
        end,
    },
    {
        name = "a sort narrows nothing -- every owned item is still shown",
        fn = function()
            for _, spec in ipairs(Party.SORTS) do
                local p = panel(fourItemStash(), spec.id)
                assert(#p:visibleStash() == 4, spec.id .. " must show the whole stash")
            end
        end,
    },
}
