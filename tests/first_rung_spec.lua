-- A ROOT'S FIRST RUNG (2026-11-13): the day a class is unlocked it stands at level 0, and its house sells
-- what Act 0 handed the company and what the unlock itself gives -- nothing else. Everything the ladder
-- once seated on rung 0 waits on Class.FIRST_RUNG_EVICTED_TO. See Class.opensFirst.
local Class = require("models.class")
local Item = require("models.item")
local Vendor = require("models.vendor")

local function rootShelf(class) return Vendor.forClass(class) end

return {
    {
        name = "Class.ACT0_KIT is exactly what the company owns when Act 0 ends",
        fn = function()
            local Player = require("models.player")
            local Character = require("models.character")
            local prologue = require("states.prologue")
            local p = Player.new and Player.new() or Player.reset()
            p = p or Player.current
            prologue.skip(p)
            local owned = {}
            local function add(it)
                local id = type(it) == "table" and it.id or it
                if id and Item.defs[id] then owned[id] = true end
            end
            for _, c in ipairs(p.roster) do for _, it in ipairs(Character.eachItem(c)) do add(it) end end
            for _, it in ipairs(p.stash or {}) do add(it) end
            for _, it in ipairs(p.pack or {}) do add(it) end
            local bad = {}
            for id in pairs(owned) do
                if not Class.ACT0_KIT[id] then bad[#bad + 1] = "missing from the kit: " .. id end
            end
            for id in pairs(Class.ACT0_KIT) do
                if not owned[id] then bad[#bad + 1] = "Act 0 no longer hands over: " .. id end
            end
            table.sort(bad)
            assert(#bad == 0, table.concat(bad, "\n  "))
        end,
    },
    {
        name = "a root unlocked at level 0 sells only Act 0's kit and its unlock gifts",
        fn = function()
            local bad = {}
            for class in pairs(Class.defs) do
                if Class.isRoot(class) and Class.isPlayable(class) then
                    local vendorId = rootShelf(class)
                    assert(vendorId, "no house shelves " .. class)
                    local open = {}
                    for _, row in ipairs(Vendor.stock(vendorId, 0, nil, {}, {})) do
                        if not row.locked and row.class == class then open[row.id] = true end
                    end
                    for id in pairs(open) do
                        if not Class.opensFirst(id, Item.defs[id]) then
                            bad[#bad + 1] = class .. " opens " .. id .. " on rung 0"
                        end
                    end
                    for _, gift in ipairs({ Class.ROOT_GIFTS[class], Class.AVATAR_GIFTS[class] }) do
                        if gift and Item.defs[gift] and not open[gift] then
                            bad[#bad + 1] = class .. " does not sell its gift " .. gift .. " on rung 0"
                        end
                    end
                end
            end
            table.sort(bad)
            assert(#bad == 0, table.concat(bad, "\n  "))
        end,
    },
    {
        name = "the Lodge's first rung is Mark Target and Called Shot, beside what Act 0 carried",
        fn = function()
            local open = {}
            for _, row in ipairs(Vendor.stock(rootShelf("hunter"), 0, nil, {}, {})) do
                if not row.locked then open[row.id] = true end
            end
            assert(open.ability_mark_target and open.ability_called_shot, "both hunter gifts on sale")
            assert(not open.consumable_net and not open.weapon_iron_longbow and not open.utility_endurance,
                "the old opening rack waits for rung 2")
            local two = {}
            for _, row in ipairs(Vendor.stock(rootShelf("hunter"), 2, nil, {}, {})) do
                if not row.locked then two[row.id] = true end
            end
            assert(two.consumable_net and two.weapon_iron_longbow and two.utility_endurance,
                "and opens there")
        end,
    },
}
