-- The Draft-mode store: what a round offers to buy. Each roll shows a few CHARACTERS drawn from the
-- run's draftable pool (which grows by round, see models/draft_run.lua) and a rather larger row of GEAR
-- scaled to the round, at prices the run's own wallet pays.
--
-- GEAR IS THE DRAFT. A bought character arrives as a chassis -- its signature weapon and verb, and
-- eight empty cells (models/draft_chassis.lua) -- so almost everything a party fights with is a piece
-- the player chose off the gear row and read before buying. The unit row decides which four bodies
-- carry the build, not what the build is.
--
-- Gear is drawn from THE RUN'S SHELF (DraftShop.shelf): a fixed subset of the item list, seeded once per
-- run, so the same pieces recur and become learnable instead of a fresh 472-item lottery every roll.
--
-- The roll is DETERMINISTIC from the run's seed, its round, and how many times it has been rerolled
-- (Combat.newRandom, the same pure-Lua RNG the arena seeds use) -- so a run reproduces exactly and the
-- roll is testable without any RNG surprise. Freezing carries chosen slots across the next roll.
--
-- Gear is priced on the draft's own flat Super-Auto-Pets scale (DraftShop.gearPrice), NOT the campaign
-- Vendor price -- the whole round budget is ~10g, so a 60g sword would be unbuyable. Pure model, no
-- love.graphics -- loads headless.

local Item = require("models.item")
local Character = require("models.character")
local Combat = require("models.combat")
local DraftRun = require("models.draft_run")
local DraftChassis = require("models.draft_chassis")

local DraftShop = {}

-- How many of each kind a roll shows. GEAR outnumbers UNITS, because gear is the draft: a bought unit is
-- stripped to its chassis (models/draft_chassis.lua), so almost everything a party ends up carrying is a
-- piece the player picked off this row. Three unit offers still fills the four-unit party across rounds
-- one and two on a 10g budget at 3g each. The floor is that round 1 must field >= UNIT_SLOTS units --
-- data/draft/pool.lua's opening wave has seven, so three is safe.
DraftShop.UNIT_SLOTS = 3
DraftShop.GEAR_SLOTS = 4

-- What a drafted character costs. Flat, like the units in the game that inspired this: the decision is
-- WHICH unit and whether to chase a duplicate, not affording one.
DraftShop.UNIT_PRICE = 3

-- What gear costs in the DRAFT economy: a flat, Super-Auto-Pets-scale price, NOT the campaign's Vendor
-- price. The whole draft budget is ~10g/round (DraftRun.roundBudget) and a unit is 3g, so an iron
-- sword's 60g campaign tag would be unbuyable here -- the mode reprices gear onto its own small scale. A
-- forged (+N) piece costs a touch more than a plain one so a late shelf is not effectively free.
DraftShop.GEAR_PRICE = 3
function DraftShop.gearPrice(level)
    return DraftShop.GEAR_PRICE + (level or 0)
end

-- What selling a piece of draft gear returns: half its DRAFT price (floored, at least a coin) -- never
-- Vendor.sellValue, which is half the CAMPAIGN price and would pay ~30g for a 3g-bought sword.
function DraftShop.gearSellValue(item)
    return math.max(1, math.floor(DraftShop.gearPrice(item and item.level or 0) / 2))
end

-- Rerolling the shop costs a coin. Cheap enough to be a real lever, dear enough to trade against a buy.
DraftShop.REROLL_COST = 1

-- The upgrade level gear is offered at in `round`: gently climbing so early shelves are plain and later
-- ones are forged, capped at the item ceiling. Monotonic in round by construction.
function DraftShop.gearLevel(round)
    return math.min(Item.MAX_LEVEL, math.floor((math.max(1, round or 1) - 1) / 2))
end

-- The most expensive CAMPAIGN-price gear the shelf shows in `round`, used purely as a POWER gate so an
-- early store is not papered with endgame plate (the draft charges its own flat price -- see gearPrice
-- -- so this is about which items are tier-appropriate, not what they cost). Climbs with the round.
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

-- Every priced, unbound item in the game, sorted -- the universe a run's shelf is drawn from. Computed
-- once: Item.defs does not change at runtime.
local allGearIds
local function everyGearId()
    if not allGearIds then
        allGearIds = {}
        for id, def in pairs(Item.defs) do
            if def.price and not def.bound then allGearIds[#allGearIds + 1] = id end
        end
        table.sort(allGearIds)
    end
    return allGearIds
end

-- ---------------------------------------------------------------------------
-- The run shelf
-- ---------------------------------------------------------------------------

-- How many items each price band contributes to a run's shelf. See DraftShop.shelf for why the draw is
-- banded rather than uniform.
DraftShop.SHELF_PER_BAND = 6

-- The highest round a shelf is banded out to -- a run reaches roughly twelve rounds (the round advances
-- after EVERY battle, win or loss), so this covers the whole ladder with room over.
DraftShop.SHELF_BANDS = 12

-- THE RUN'S SHELF: the fixed subset of gear this run will ever be offered, drawn once from the run's
-- seed. Every roll for the rest of the run draws from it.
--
-- Why a run has a shelf at all: the old shop drew from every priced item under the round's cap, which is
-- ~12 ids at round 1 but hundreds of the 472 by mid-run. Across a twelve-round run you never saw the
-- same piece twice -- so you never learned one, could never plan around one coming back, and item
-- merging (which needs a second copy of the same id, see DraftRun.canMergeItems) was pure luck. A
-- shelf makes repeats the norm, which is what makes the items learnable and merging reachable.
--
-- The draw is BANDED, not uniform. Gear is gated by DraftShop.gearPriceCap(round), and only about a
-- dozen of the 472 items sit under round 1's cap of 70 -- a uniform draw of SHELF_PER_BAND *
-- SHELF_BANDS ids would land maybe two of them and leave the opening shop unable to fill a row. So the
-- candidates are partitioned by the bands the successive caps carve out, and each band contributes its
-- own draw. That guarantees every round a workable eligible set, keeps the shelf growing monotonically
-- with the round, and -- because the low band is so small -- puts half the cheap tier on your shelf
-- every run, exactly where repeats matter most.
--
-- Derived from run.rngSeed, which snapshot/restore already persists (models/draft_run.lua), so the shelf
-- survives a quit with NO save-schema change. Memoized on `run._shelf`, a leading-underscore cache the
-- snapshot deliberately does not write.
function DraftShop.shelf(run)
    if run._shelf then return run._shelf end

    local rng = Combat.newRandom((run.rngSeed or 1) * 7 + 3)
    local candidates = everyGearId()

    -- Partition by band: band r holds the ids the round-r cap admits but the round-(r-1) cap did not.
    local bands, lower = {}, 0
    for r = 1, DraftShop.SHELF_BANDS do
        local cap = DraftShop.gearPriceCap(r)
        local band = {}
        for _, id in ipairs(candidates) do
            local price = Item.defs[id].price
            if price > lower and price <= cap then band[#band + 1] = id end
        end
        bands[r] = band
        lower = cap
    end

    local shelf, seen = {}, {}
    for r = 1, DraftShop.SHELF_BANDS do
        for _, id in ipairs(sampleDistinct(rng, bands[r], DraftShop.SHELF_PER_BAND)) do
            if not seen[id] then
                seen[id] = true
                shelf[#shelf + 1] = id
            end
        end
    end
    table.sort(shelf)

    run._shelf = shelf
    return shelf
end

-- The gear ids buyable this round: the RUN'S SHELF filtered to what the round's power gate admits.
-- Sorted for a reproducible sample. A fresh list each call.
function DraftShop.gearCandidates(run)
    local cap = DraftShop.gearPriceCap(run and run.round)
    local ids = {}
    for _, id in ipairs(DraftShop.shelf(run or {})) do
        if Item.defs[id].price <= cap then ids[#ids + 1] = id end
    end
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
        price = DraftShop.gearPrice(level),
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
    local gearIds = DraftShop.gearCandidates(run)

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

-- Buy the character in `entry`: spend its price, instantiate it as a CHASSIS (stripped to its signature
-- weapon and verb -- see models/draft_chassis.lua for why a drafted body does not arrive wearing its
-- whole blueprint kit), and bench it. Removes the entry from the shop on success. Returns the new
-- character, or nil + reason ("gold" | "bench full" | "gone").
function DraftShop.buyUnit(run, entry)
    if not entry or entry.kind ~= "unit" then return nil, "gone" end
    if DraftRun.rosterFull(run) then return nil, "roster full" end
    if not DraftRun.canAfford(run, entry.price) then return nil, "gold" end
    local char = DraftChassis.instantiate(entry.id)
    if not char then return nil, "gone" end
    DraftRun.spend(run, entry.price)
    DraftRun.addUnit(run, char)
    DraftShop.take(run.shop and run.shop.units, entry)
    return char
end

-- Buy the character in `entry` and combine it straight INTO `target`, an already-drafted unit of the
-- same blueprint -- what dragging a store card onto its own kind does. Exactly a buy followed by a merge
-- and nothing else, so the one-motion shortcut can never pay out differently from the long way round:
-- the kept unit climbs one growth level, and the bought chassis's signatures cascade into the target's
-- copies of the very same pieces (DraftRun.mergeUnit), so a duplicate purchase upgrades the gear rather
-- than littering the stash with a second weapon the unit is already holding.
--
-- Deliberately does NOT check rosterFull. The bought body is consumed by the merge in the same breath and
-- never occupies a seat, so a full formation and a full bench are no reason to refuse an upgrade -- which
-- is the whole point of the shortcut late in a run, when there is nowhere to park a duplicate.
--
-- Returns the merge result ({ unit, fromLevel, toLevel }), or nil + reason ("gone" | "gold" | "cannot merge").
function DraftShop.buyUnitInto(run, entry, target)
    if not entry or entry.kind ~= "unit" then return nil, "gone" end
    if not DraftRun.canMergeIdInto(entry.id, target) then return nil, "cannot merge" end
    if not DraftRun.canAfford(run, entry.price) then return nil, "gold" end
    local char = DraftChassis.instantiate(entry.id)
    if not char then return nil, "gone" end
    local result, why = DraftRun.mergeUnit(run, char, target)
    if not result then return nil, why or "cannot merge" end
    DraftRun.spend(run, entry.price)
    DraftShop.take(run.shop and run.shop.units, entry)
    return result
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
