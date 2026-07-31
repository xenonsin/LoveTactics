-- Tests for models/draft_shop.lua: the round store. A roll is deterministic from the run's seed and
-- round, gear scales with the round, freezing carries slots, and buying spends and places. Headless.

local DraftShop = require("models.draft_shop")
local DraftRun = require("models.draft_run")
local Item = require("models.item")

-- The ids a shop section is offering, for comparing two rolls.
local function ids(section)
    local out = {}
    for i, e in ipairs(section) do out[i] = e.id end
    return out
end

local function sameList(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do if a[i] ~= b[i] then return false end end
    return true
end

return {
    {
        name = "a roll fills both sections to their slot counts",
        fn = function()
            local run = DraftRun.new(42)
            run.round = 5 -- a deep enough pool to fill the unit slots
            DraftShop.roll(run)
            assert(#run.shop.units == DraftShop.UNIT_SLOTS, "the unit shelf is full")
            assert(#run.shop.gear == DraftShop.GEAR_SLOTS, "the gear shelf is full")
        end,
    },
    {
        name = "the same seed and round roll the same shop -- reproducible, no RNG surprise",
        fn = function()
            local a = DraftRun.new(999); a.round = 4; DraftShop.roll(a)
            local b = DraftRun.new(999); b.round = 4; DraftShop.roll(b)
            assert(sameList(ids(a.shop.units), ids(b.shop.units)), "units match")
            assert(sameList(ids(a.shop.gear), ids(b.shop.gear)), "gear matches")

            local c = DraftRun.new(1000); c.round = 4; DraftShop.roll(c)
            assert(not sameList(ids(a.shop.units), ids(c.shop.units))
                or not sameList(ids(a.shop.gear), ids(c.shop.gear)), "a different seed rolls differently")
        end,
    },
    {
        name = "gear level scales with the round and never exceeds the item ceiling",
        fn = function()
            local prev = -1
            for round = 1, 30 do
                local level = DraftShop.gearLevel(round)
                assert(level >= prev, "gear level never drops as rounds climb (round " .. round .. ")")
                assert(level <= Item.MAX_LEVEL, "and never passes the ceiling")
                prev = level
            end
            assert(DraftShop.gearLevel(10) > DraftShop.gearLevel(1), "later rounds forge higher gear")
        end,
    },
    {
        name = "every offered gear entry is a real, priced item at the round's level",
        fn = function()
            local run = DraftRun.new(7); run.round = 6; DraftShop.roll(run)
            local level = DraftShop.gearLevel(6)
            for _, entry in ipairs(run.shop.gear) do
                local def = Item.defs[entry.id]
                assert(def and def.price, "a gear entry names a real priced item: " .. tostring(entry.id))
                assert(entry.level == level, "offered at the round's gear level")
                assert(entry.price and entry.price > 0, "with a price")
            end
        end,
    },
    {
        name = "freezing a slot carries it across the next roll; the rest re-roll",
        fn = function()
            local run = DraftRun.new(5); run.round = 5; DraftShop.roll(run)
            local frozen = run.shop.units[1]
            DraftShop.toggleFreeze(frozen)
            DraftShop.reroll(run)

            local held = false
            for _, e in ipairs(run.shop.units) do if e == frozen then held = true end end
            assert(held, "the frozen entry survived the reroll")
        end,
    },
    {
        name = "buying a unit spends its price and fields it; an empty wallet is refused",
        fn = function()
            local run = DraftRun.new(3); run.round = 3; DraftShop.roll(run)
            run.gold = DraftShop.UNIT_PRICE
            local entry = run.shop.units[1]
            local char = DraftShop.buyUnit(run, entry)
            assert(char and char.id == entry.id, "the drafted unit is the one bought")
            assert(run.gold == 0, "its price was spent")
            assert(DraftRun.formationCount(run) == 1 and DraftRun.cellOf(run, char),
                "and it auto-fields into the formation")

            local broke = DraftShop.buyUnit(run, run.shop.units[1])
            assert(broke == nil, "with no gold left, the next buy is refused")
        end,
    },
    {
        name = "a reroll costs a coin and refuses when the coin is not there",
        fn = function()
            local run = DraftRun.new(3); run.round = 3; DraftShop.roll(run)
            run.gold = DraftShop.REROLL_COST
            assert(DraftShop.reroll(run), "a reroll you can afford goes through")
            assert(run.gold == 0, "and costs a coin")
            local nope, why = DraftShop.reroll(run)
            assert(nope == nil and why == "gold", "a reroll you can't afford is refused")
        end,
    },
}
