-- The Draft-mode store: what a round offers to buy. Each roll shows a handful of CHARACTERS drawn
-- from the run's draftable pool (which grows by round, see models/draft_run.lua) and a handful of
-- GEAR entries scaled to the round, at prices the run's own wallet pays.
--
-- The roll is DETERMINISTIC from the run's seed, its round, and how many times it has been rerolled
-- (Combat.newRandom, the same pure-Lua RNG the arena seeds use) -- so a run reproduces exactly and the
-- roll is testable without any RNG surprise. Freezing carries chosen slots across the next roll.
--
-- Gear reuses the vendor's price math (Vendor.priceFor scales +50%/level) rather than inventing its
-- own, so a "+2" sword costs here what it would anywhere. Pure model, no love.graphics -- loads headless.

local Item = require("models.item")
local Character = require("models.character")
local Combat = require("models.combat")
local Vendor = require("models.vendor")
local DraftRun = require("models.draft_run")

local DraftShop = {}

-- How many of each kind a roll shows.
DraftShop.UNIT_SLOTS = 4
DraftShop.GEAR_SLOTS = 3

-- What a drafted character costs. Flat, like the units in the game that inspired this: the decision is
-- WHICH unit and whether to chase a duplicate, not affording one.
DraftShop.UNIT_PRICE = 3

-- Rerolling the shop costs a coin. Cheap enough to be a real lever, dear enough to trade against a buy.
DraftShop.REROLL_COST = 1

-- The upgrade level gear is offered at in `round`: gently climbing so early shelves are plain and later
-- ones are forged, capped at the item ceiling. Monotonic in round by construction.
function DraftShop.gearLevel(round)
    return math.min(Item.MAX_LEVEL, math.floor((math.max(1, round or 1) - 1) / 2))
end

-- The most expensive BASE price gear the shelf shows in `round`, so an early store is not papered with
-- plate the round's budget could never touch. Climbs with the round.
function DraftShop.gearPriceCap(round)
    return 40 + 30 * (math.max(1, round or 1))
end

-- ---------------------------------------------------------------------------
-- Rolling
-- ---------------------------------------------------------------------------

-- Pick up to `k` distinct entries from `list` using `rng` (an n -> 1..n draw). Fisher-Yates-ish:
-- swaps chosen items to the front of a copy so no index is drawn twice. Returns the picks in draw order.
local function sampleDistinct(rng, list, k)
    local pool = {}
    for i, v in ipairs(list) do pool[i] = v end
    local picks = {}
    local n = #pool
    k = math.min(k, n)
    for i = 1, k do
        local j = i + (rng(n - i + 1) - 1) -- a slot in the still-unpicked tail [i..n]
        pool[i], pool[j] = pool[j], pool[i]
        picks[i] = pool[i]
    end
    return picks
end

-- The gear ids buyable in `round`: priced, unbound, and no dearer at base than the round's cap. Sorted
-- for a reproducible sample. A fresh list each call.
function DraftShop.gearCandidates(round)
    local cap = DraftShop.gearPriceCap(round)
    local ids = {}
    for id, def in pairs(Item.defs) do
        if def.price and def.price <= cap and not def.bound then
            ids[#ids + 1] = id
        end
    end
    table.sort(ids)
    return ids
end

local function unitEntry(id)
    local def = Character.defs[id]
    return {
        kind = "unit",
        id = id,
        name = def and def.name or id,
        price = DraftShop.UNIT_PRICE,
        frozen = false,
    }
end

local function gearEntry(id, level)
    local def = Item.defs[id]
    return {
        kind = "gear",
        id = id,
        name = def and def.name or id,
        type = def and def.type,
        level = level,
        price = Vendor.priceFor(def and def.price, level),
        description = def and def.description,
        flavor = def and def.flavor,
        frozen = false,
    }
end

-- Fill a section to its slot count: keep every FROZEN entry from the previous roll, then draw fresh
-- entries for the empty slots from `candidates` via `make(id)`. Frozen entries hold their place;
-- everything else is re-rolled.
local function rollSection(rng, previous, candidates, slots, make)
    local kept = {}
    for _, entry in ipairs(previous or {}) do
        if entry.frozen then kept[#kept + 1] = entry end
    end
    local need = slots - #kept
    if need > 0 then
        for _, id in ipairs(sampleDistinct(rng, candidates, need)) do
            kept[#kept + 1] = make(id)
        end
    end
    return kept
end

-- Roll (or re-roll) the run's shop. Keeps frozen slots, re-samples the rest. Deterministic from
-- (seed, round, rerolls); the state layer bumps run.rerolls and calls this again for a paid reroll.
-- Returns run.shop.
function DraftShop.roll(run)
    run.shop = run.shop or {}
    local seed = (run.rngSeed or 1) + (run.round or 1) * 1009 + (run.rerolls or 0) * 7919
    local rng = Combat.newRandom(seed)

    local pool = DraftRun.pool(run.round)
    local level = DraftShop.gearLevel(run.round)
    local gearIds = DraftShop.gearCandidates(run.round)

    run.shop.units = rollSection(rng, run.shop.units, pool, DraftShop.UNIT_SLOTS, unitEntry)
    run.shop.gear = rollSection(rng, run.shop.gear, gearIds, DraftShop.GEAR_SLOTS,
        function(id) return gearEntry(id, level) end)
    return run.shop
end

-- Toggle whether an entry survives the next roll. The entry is one of the tables in run.shop.units /
-- run.shop.gear.
function DraftShop.toggleFreeze(entry)
    if entry then entry.frozen = not entry.frozen end
end

-- Pay for a reroll and roll again. Returns the new shop, or nil + "gold" if the coin is not there.
function DraftShop.reroll(run)
    if not DraftRun.spend(run, DraftShop.REROLL_COST) then return nil, "gold" end
    run.rerolls = (run.rerolls or 0) + 1
    return DraftShop.roll(run)
end

-- ---------------------------------------------------------------------------
-- Buying
-- ---------------------------------------------------------------------------

-- Buy the character in `entry`: spend its price, instantiate it, and bench it. Removes the entry from
-- the shop on success. Returns the new character, or nil + reason ("gold" | "bench full" | "gone").
function DraftShop.buyUnit(run, entry)
    if not entry or entry.kind ~= "unit" then return nil, "gone" end
    if DraftRun.benchFull(run) then return nil, "bench full" end
    if not DraftRun.canAfford(run, entry.price) then return nil, "gold" end
    local char = Character.instantiate(entry.id)
    if not char then return nil, "gone" end
    DraftRun.spend(run, entry.price)
    DraftRun.addUnit(run, char)
    DraftShop.take(run.shop and run.shop.units, entry)
    return char
end

-- Buy the gear in `entry`: spend its price, instantiate it at the offered level, and drop it in the run
-- stash (the loadout screen slots it from there). Returns the item, or nil + reason ("gold" | "gone").
function DraftShop.buyGear(run, entry)
    if not entry or entry.kind ~= "gear" then return nil, "gone" end
    if not DraftRun.canAfford(run, entry.price) then return nil, "gold" end
    local item = Item.instantiate(entry.id, nil, entry.level)
    if not item then return nil, "gone" end
    DraftRun.spend(run, entry.price)
    run.stash = run.stash or {}
    run.stash[#run.stash + 1] = item
    DraftShop.take(run.shop and run.shop.gear, entry)
    return item
end

-- Remove `entry` from `section` (a bought item leaves the shelf). Safe on nil.
function DraftShop.take(section, entry)
    for i, e in ipairs(section or {}) do
        if e == entry then table.remove(section, i) return true end
    end
    return false
end

return DraftShop
