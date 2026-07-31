-- Tests for models/draft_shop.lua: the round store. A roll is deterministic from the run's seed and
-- round, gear scales with the round, freezing carries slots, and buying spends and places. Headless.

local DraftShop = require("models.draft_shop")
local DraftRun = require("models.draft_run")
local Character = require("models.character")
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
        name = "buying a unit onto its own kind buys AND combines in one motion",
        fn = function()
            -- What dragging a store card onto a matching drafted unit does (states/draft.lua).
            local run = DraftRun.new(3); run.round = 3; DraftShop.roll(run)
            run.gold = DraftShop.UNIT_PRICE * 2
            local entry = run.shop.units[1]
            local first = DraftShop.buyUnit(run, entry)
            assert(first, "the first copy is drafted normally")

            -- Freeze the same id back onto the shelf: roll again and find a card of the kept unit's kind.
            run.shop.units[#run.shop.units + 1] =
                { kind = "unit", id = first.id, name = first.name, price = DraftShop.UNIT_PRICE }
            local dupe = run.shop.units[#run.shop.units]

            local startLevel = first.level or 1
            local result = DraftShop.buyUnitInto(run, dupe, first)
            assert(result, "the duplicate card combines into the unit it was dropped on")
            assert(result.toLevel == startLevel + 1 and first.level == startLevel + 1,
                "the kept unit climbed exactly one level")
            assert(run.gold == 0, "and the card was paid for")
            assert(DraftRun.formationCount(run) == 1, "the bought body was consumed, not seated")
            local stillOffered = false
            for _, e in ipairs(run.shop.units) do if e == dupe then stillOffered = true end end
            assert(not stillOffered, "the card left the shelf")
        end,
    },
    {
        name = "a bought duplicate upgrades the gear it shares instead of littering the stash",
        fn = function()
            -- The headline case, and the mode's most common action: every duplicate purchase arrives as a
            -- chassis carrying a fresh copy of the target's OWN signature weapon. Stashing those turned the
            -- most satisfying action into the biggest source of clutter; now they cascade into the grid.
            local run = DraftRun.new(3); run.round = 3; DraftShop.roll(run)
            run.gold = DraftShop.UNIT_PRICE * 2
            local kept = DraftShop.buyUnit(run, run.shop.units[1])
            assert(kept and Character.itemCount(kept) > 0, "the chassis carries at least its signature")
            assert(#run.stash == 0, "and a plain purchase stashes nothing")

            local before = {}
            for cell = 1, Character.MAX_INVENTORY do
                local item = kept.inventory[cell]
                if item then before[cell] = item.level or 0 end
            end

            local dupe = { kind = "unit", id = kept.id, name = kept.name, price = DraftShop.UNIT_PRICE }
            assert(DraftShop.buyUnitInto(run, dupe, kept), "the duplicate combines in")

            assert(#run.stash == 0, "the bought body's signatures were absorbed, not dumped in the stash")
            for cell, level in pairs(before) do
                assert(kept.inventory[cell] and kept.inventory[cell].level == level + 1,
                    "each shared piece rose one level in the cell it already occupied")
            end
        end,
    },
    {
        name = "a buy-and-combine is refused for a mismatch or an empty wallet, and costs nothing",
        fn = function()
            local run = DraftRun.new(3); run.round = 3; DraftShop.roll(run)
            run.gold = DraftShop.UNIT_PRICE
            local kept = DraftShop.buyUnit(run, run.shop.units[1])
            assert(kept, "one unit drafted")

            local other = { kind = "unit", id = "character_mage", name = "Mage", price = DraftShop.UNIT_PRICE }
            if kept.id ~= "character_mage" then
                local nope, why = DraftShop.buyUnitInto(run, other, kept)
                assert(nope == nil and why == "cannot merge", "a different blueprint never combines")
            end

            local dupe = { kind = "unit", id = kept.id, name = kept.name, price = DraftShop.UNIT_PRICE }
            local broke, why2 = DraftShop.buyUnitInto(run, dupe, kept)
            assert(broke == nil and why2 == "gold", "an empty wallet refuses the combine")
            assert(run.gold == 0 and (kept.level or 1) == 1, "a refused combine spends nothing and grows nothing")
        end,
    },
    {
        name = "a buy-and-combine goes through even with the formation and bench both full",
        fn = function()
            -- The point of the shortcut late in a run: there is nowhere to park a duplicate, but the
            -- upgrade should still be buyable, because the bought body never takes a seat.
            local run = DraftRun.new(11); run.round = 5; DraftShop.roll(run)
            run.gold = 99
            local kept = DraftShop.buyUnit(run, run.shop.units[1])
            for _ = 1, DraftRun.PARTY_MAX + DraftRun.BENCH_MAX do
                DraftRun.addUnit(run, require("models.character").instantiate("character_mage"))
            end
            assert(DraftRun.rosterFull(run), "no room anywhere for another body")

            local dupe = { kind = "unit", id = kept.id, name = kept.name, price = DraftShop.UNIT_PRICE }
            assert(DraftShop.buyUnitInto(run, dupe, kept), "the combine is still allowed")
            assert(kept.level == 2, "and it landed on the kept unit")
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

    -- --- the run shelf ------------------------------------------------------
    {
        name = "a run's shelf is fixed and derived from its seed alone",
        fn = function()
            local a, b = DraftRun.new(77), DraftRun.new(77)
            assert(sameList(DraftShop.shelf(a), DraftShop.shelf(b)), "the same seed shelves the same items")

            a.round = 9 -- the shelf is the RUN's, not the round's
            assert(sameList(DraftShop.shelf(a), DraftShop.shelf(b)), "and the round never re-draws it")

            local c = DraftRun.new(78)
            assert(not sameList(DraftShop.shelf(a), DraftShop.shelf(c)), "a different seed shelves differently")
        end,
    },
    {
        name = "the shelf survives a save round-trip, since it rides on the seed",
        fn = function()
            local run = DraftRun.new(4242); run.round = 6
            local before = DraftShop.shelf(run)
            local back = DraftRun.restore(DraftRun.snapshot(run))
            assert(sameList(before, DraftShop.shelf(back)), "the reloaded run shops the same shelf")
        end,
    },
    {
        name = "every round can fill its gear row off the shelf",
        fn = function()
            -- The reason the shelf draw is banded: a uniform draw would leave round 1 (cap 70, which only
            -- a dozen of the ~470 priced items clear) unable to fill a row.
            for seed = 1, 8 do
                local run = DraftRun.new(seed * 13)
                for round = 1, 12 do
                    run.round = round
                    local n = #DraftShop.gearCandidates(run)
                    assert(n >= DraftShop.GEAR_SLOTS,
                        "seed " .. seed .. " round " .. round .. " offers only " .. n .. " items")
                end
            end
        end,
    },
    {
        name = "the shelf's eligible set only grows as the round climbs",
        fn = function()
            local run = DraftRun.new(2024)
            local prev = -1
            for round = 1, 12 do
                run.round = round
                local n = #DraftShop.gearCandidates(run)
                assert(n >= prev, "round " .. round .. " offers fewer items than the one before")
                prev = n
            end
            run.round = 1; local early = #DraftShop.gearCandidates(run)
            run.round = 12; local late = #DraftShop.gearCandidates(run)
            assert(late > early, "a late run shops a wider shelf than an early one")
        end,
    },
    {
        name = "a roll only ever offers gear from the run's own shelf",
        fn = function()
            local run = DraftRun.new(31337)
            local onShelf = {}
            for _, id in ipairs(DraftShop.shelf(run)) do onShelf[id] = true end
            for round = 1, 12 do
                run.round = round
                run.shop = nil
                DraftShop.roll(run)
                for _, entry in ipairs(run.shop.gear) do
                    assert(onShelf[entry.id], "round " .. round .. " offered off-shelf gear: " .. entry.id)
                    assert(Item.defs[entry.id].price <= DraftShop.gearPriceCap(round),
                        "and it respected the round's power gate")
                end
            end
        end,
    },
    {
        name = "the shelf repeats -- the same piece recurs across a run, so it can be learned and merged",
        fn = function()
            -- The old open pool made a repeat a fluke, which put item merging (same id AND same level)
            -- out of reach. Roll a run's whole ladder and assert some id comes back.
            local run = DraftRun.new(8675309)
            local seen, repeated = {}, false
            for round = 1, 12 do
                run.round = round
                for _ = 1, 6 do
                    run.shop = nil
                    run.rerolls = (run.rerolls or 0) + 1
                    DraftShop.roll(run)
                    for _, entry in ipairs(run.shop.gear) do
                        if seen[entry.id] then repeated = true end
                        seen[entry.id] = true
                    end
                end
            end
            assert(repeated, "no gear ever came back around -- the shelf is not doing its job")
        end,
    },
    {
        name = "a bought unit arrives as a chassis, not wearing its whole blueprint kit",
        fn = function()
            local Character = require("models.character")
            local run = DraftRun.new(11); run.round = 5; DraftShop.roll(run)
            run.gold = DraftShop.UNIT_PRICE
            local entry = run.shop.units[1]
            local char = DraftShop.buyUnit(run, entry)
            assert(char, "the unit was bought")
            assert(Character.itemCount(char) <= 2, "it carries at most its two signatures")
            assert(Character.itemCount(Character.instantiate(entry.id)) >= Character.itemCount(char),
                "which is no more than its blueprint would have given it")
        end,
    },
}
