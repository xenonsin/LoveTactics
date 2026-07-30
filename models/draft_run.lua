-- A Draft-mode run: the roguelike-draft loop that wraps the game's tactical combat in a
-- Super-Auto-Pets-style economy. Each round grants a budget to draft characters and buy gear, you
-- combine duplicates to strengthen them, then a battle against another player's team (live or a
-- stored build) decides a win or a loss. Ten wins takes the run; three losses ends it.
--
-- This module is the RULES of that loop and nothing else -- the shop roll lives in
-- models/draft_shop.lua, matchmaking in models/draft_match.lua, and the screens in states/draft.lua.
-- It is pure model (no love.graphics; love.filesystem only in the disk section), so it loads under the
-- headless tests. Its own wallet (run.gold) is deliberately separate from the campaign's player.gold:
-- a draft run must never spend or earn the player's real gold.
--
-- Persistence reuses the save file's answer to "what of a character is worth writing down"
-- (Save.snapshotCharacter / restoreCharacter), the same shape a build uses, so a bench survives a
-- quit and reloads at its exact leveled, geared state.

local Character = require("models.character")
local Item = require("models.item")
local Growth = require("models.growth")
local Save = require("models.save")
local Registry = require("models.registry")

local DraftRun = {}

-- Terminal thresholds (the user's spec: 3 lives, first to 10 wins).
DraftRun.WIN_TARGET = 10
DraftRun.LIVES = 3

-- The deployable party cap -- the same four the tactical game fields (Player.MAX_PARTY). Named here
-- rather than required so this module stays player-free, like models/vendor.lua.
DraftRun.PARTY_MAX = 4

-- How many units the bench may hold at once: the four you field plus room for spares and merge fodder.
DraftRun.BENCH_MAX = 8

-- The ceiling a unit's level can be pushed to by merging duplicates. Growth ramps hard (a level is a
-- full class's worth of stats), so a handful of merges is already a decisive unit -- this keeps a
-- lucky duplicate streak from running away with the whole run.
DraftRun.MAX_UNIT_LEVEL = 6

-- The gold budget granted at the START of `round`. Refreshed each round (Super Auto Pets style:
-- unspent gold does not bank), climbing gently so later rounds can afford the deeper, pricier shelves
-- the pool opens. Named as a curve so it is a single tuning knob.
DraftRun.BASE_BUDGET = 10
DraftRun.BUDGET_STEP = 2
function DraftRun.roundBudget(round)
    return DraftRun.BASE_BUDGET + DraftRun.BUDGET_STEP * math.max(0, (round or 1) - 1)
end

-- ---------------------------------------------------------------------------
-- The draftable pool (grows by round)
-- ---------------------------------------------------------------------------

-- The unlock waves, loaded once. data/draft/pool.lua is a single ordered list, so Registry (which
-- keys a folder by filename) hands it back under "pool"; unwrap to the list.
DraftRun.poolWaves = (Registry.load("data/draft", "data.draft") or {}).pool or {}

-- Every character id draftable at `round`: the union of all waves whose `round` has been reached,
-- filtered to blueprints that actually exist (a still-`pending` exemplar id listed in the waves is
-- skipped rather than offered as a phantom unit). Deterministic order -- sorted -- so a seeded shop
-- roll over this list is reproducible. Returns a fresh list.
function DraftRun.pool(round)
    round = round or 1
    local seen, ids = {}, {}
    for _, wave in ipairs(DraftRun.poolWaves) do
        if (wave.round or 1) <= round then
            for _, id in ipairs(wave.ids or {}) do
                if not seen[id] and Save.known(Character.defs, id) then
                    seen[id] = true
                    ids[#ids + 1] = id
                end
            end
        end
    end
    table.sort(ids)
    return ids
end

-- ---------------------------------------------------------------------------
-- Starting and advancing a run
-- ---------------------------------------------------------------------------

-- A fresh run at round 1 with the opening budget and an empty bench. `seed` seeds every later shop
-- roll (models/draft_shop.lua derives its RNG from seed + round), so a run is reproducible from it.
function DraftRun.new(seed)
    return {
        round = 1,
        wins = 0,
        losses = 0,
        gold = DraftRun.roundBudget(1),
        rngSeed = seed or os.time(),
        bench = {},   -- live character instances the player has drafted
        stash = {},   -- unequipped item instances (merge fodder's gear lands here, never lost)
        shop = nil,   -- the current offering; models/draft_shop.lua fills it
    }
end

-- Has the run ended? "won" at the win target, "eliminated" once lives are spent, else nil (play on).
-- Wins take priority: reaching ten wins on the same round a third loss would fall is still a win.
function DraftRun.outcome(run)
    if (run.wins or 0) >= DraftRun.WIN_TARGET then return "won" end
    if (run.losses or 0) >= DraftRun.LIVES then return "eliminated" end
    return nil
end

-- Roll the round over: bump the counter and refresh the budget. Called by recordResult after a
-- non-terminal battle; the shop roll is the state layer's to trigger (DraftShop.roll), because only it
-- knows whether the player froze anything.
function DraftRun.advanceRound(run)
    run.round = (run.round or 1) + 1
    run.gold = DraftRun.roundBudget(run.round)
end

-- Bank a battle result ("win" | "loss") and advance the run. Returns the resulting outcome (see
-- DraftRun.outcome) so the caller can route to the shop or the terminal screen. A run already decided
-- is left untouched.
function DraftRun.recordResult(run, result)
    if DraftRun.outcome(run) then return DraftRun.outcome(run) end
    if result == "win" then
        run.wins = (run.wins or 0) + 1
    elseif result == "loss" then
        run.losses = (run.losses or 0) + 1
    end
    local outcome = DraftRun.outcome(run)
    if not outcome then DraftRun.advanceRound(run) end
    return outcome
end

-- ---------------------------------------------------------------------------
-- Gold
-- ---------------------------------------------------------------------------

function DraftRun.canAfford(run, price)
    return (run.gold or 0) >= (price or 0)
end

-- Spend `price` if it is there; returns true on success, false (and spends nothing) if it is not.
function DraftRun.spend(run, price)
    if not DraftRun.canAfford(run, price) then return false end
    run.gold = run.gold - (price or 0)
    return true
end

function DraftRun.addGold(run, amount)
    run.gold = (run.gold or 0) + (amount or 0)
end

-- ---------------------------------------------------------------------------
-- The bench
-- ---------------------------------------------------------------------------

function DraftRun.benchFull(run)
    return #(run.bench or {}) >= DraftRun.BENCH_MAX
end

-- Put a live character instance on the bench. Returns true, or false if the bench is full (the caller
-- should have checked benchFull and refunded/refused the purchase). Does NOT auto-merge -- combining
-- duplicates is an explicit player action (DraftRun.mergeUnit), so a second copy sits beside the first
-- until the player drags them together.
function DraftRun.addUnit(run, char)
    if DraftRun.benchFull(run) then return false end
    run.bench = run.bench or {}
    run.bench[#run.bench + 1] = char
    return true
end

-- The units that take the field: up to PARTY_MAX from the bench, in bench order. Draft mode fields the
-- front of the bench for v1 (the arrange screen reorders the bench, so "the front four" is the choice);
-- a spare fifth unit and merge fodder simply wait behind them. Returns a fresh list of live instances.
function DraftRun.party(run)
    local party = {}
    for i = 1, math.min(DraftRun.PARTY_MAX, #(run.bench or {})) do
        party[i] = run.bench[i]
    end
    return party
end

-- Remove `char` from the bench (a sale, or the consumed half of a merge). Returns true if it was there.
function DraftRun.removeUnit(run, char)
    for i, c in ipairs(run.bench or {}) do
        if c == char then
            table.remove(run.bench, i)
            return true
        end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Merging duplicates
-- ---------------------------------------------------------------------------

-- Two bench units combine when they are the same blueprint and the one being KEPT is below the level
-- ceiling. (Different characters never merge; two maxed copies have nowhere to grow.)
function DraftRun.canMergeUnits(source, target)
    if not source or not target or source == target then return false end
    if source.id ~= target.id then return false end
    return (target.level or 1) < DraftRun.MAX_UNIT_LEVEL
end

-- Combine `source` INTO `target`: bump the kept unit one growth level (the confirmed reuse of
-- models/growth.lua -- a merge grows a unit exactly as a prestige level-up would, reading the class
-- tally it was built with), drop the source from the bench, and keep the source's gear by moving it to
-- the run stash rather than letting it evaporate. Returns { unit, fromLevel, toLevel } or nil + reason.
function DraftRun.mergeUnit(run, source, target)
    if not DraftRun.canMergeUnits(source, target) then return nil, "cannot merge" end

    local fromLevel = target.level or 1
    Growth.resolve(target, math.min(fromLevel + 1, DraftRun.MAX_UNIT_LEVEL))

    -- The fodder's gear is not thrown away with it -- the player paid for it. It goes to the stash,
    -- where the loadout screen can re-slot it onto any unit (bound relics never move, so a generic's
    -- has nothing to strip and a companion's stays where it was authored).
    for cell = 1, Character.MAX_INVENTORY do
        local item = source.inventory and source.inventory[cell]
        if item and not Item.isBound(item) then
            run.stash = run.stash or {}
            run.stash[#run.stash + 1] = item
        end
    end

    DraftRun.removeUnit(run, source)
    return { unit = target, fromLevel = fromLevel, toLevel = target.level }
end

-- Two items combine when they are the same blueprint at the same upgrade level, and that level is
-- below the item ceiling. (An item already at Item.MAX_LEVEL has nowhere to go.)
function DraftRun.canMergeItems(a, b)
    if not a or not b or a == b then return false end
    if a.id ~= b.id then return false end
    if (a.level or 0) ~= (b.level or 0) then return false end
    return (a.level or 0) < Item.MAX_LEVEL
end

-- Combine two identical items into one a level higher: returns a FRESH instance at level+1, carrying
-- the combined stack count (so merging two stacks of a consumable keeps the count). Returns nil if the
-- two cannot merge. The caller swaps the result into the target cell and discards the source.
function DraftRun.mergeItems(a, b)
    if not DraftRun.canMergeItems(a, b) then return nil end
    local quantity = (a.quantity or 1) + (b.quantity or 1)
    return Item.instantiate(a.id, quantity, (a.level or 0) + 1)
end

-- ---------------------------------------------------------------------------
-- Persistence (snapshot <-> plain data; disk)
-- ---------------------------------------------------------------------------

-- A run as plain, scalar-only data. Bench and stash reuse the save file's character/item snapshot, so
-- a leveled, geared unit reloads exactly (Save.snapshotCharacter carries level, class tally, growth
-- and grid). Safe to Save.encode -- no functions, no love objects.
function DraftRun.snapshot(run)
    local bench = {}
    for i, char in ipairs(run.bench or {}) do bench[i] = Save.snapshotCharacter(char) end
    local stash = {}
    for i, item in ipairs(run.stash or {}) do
        stash[i] = { id = item.id, quantity = item.quantity or 1 }
        if item.level and item.level > 0 then stash[i].level = item.level end
    end
    return {
        round = run.round, wins = run.wins, losses = run.losses,
        gold = run.gold, rngSeed = run.rngSeed,
        bench = bench, stash = stash,
    }
end

-- Rebuild a run from a snapshot. Unknown content is dropped the way a save drops it (a removed
-- character or item leaves the rest of the bench intact) -- a run is the player's own progress, worth
-- salvaging in part, unlike a build handed over whole. Returns the run, or nil if the snapshot is junk.
function DraftRun.restore(snap)
    if type(snap) ~= "table" then return nil end
    local bench = {}
    for _, charSnap in ipairs(snap.bench or {}) do
        if Save.known(Character.defs, charSnap.id) then
            bench[#bench + 1] = Save.restoreCharacter(charSnap)
        end
    end
    local stash = {}
    for _, itemSnap in ipairs(snap.stash or {}) do
        if Save.known(Item.defs, itemSnap.id) then
            stash[#stash + 1] = Item.instantiate(itemSnap.id, itemSnap.quantity, itemSnap.level)
        end
    end
    return {
        round = snap.round or 1,
        wins = snap.wins or 0,
        losses = snap.losses or 0,
        gold = snap.gold or DraftRun.roundBudget(snap.round or 1),
        rngSeed = snap.rngSeed or os.time(),
        bench = bench,
        stash = stash,
        shop = nil, -- a fresh roll is cheaper than serializing one, and never stale
    }
end

DraftRun.FILE = "draft_run.lua"

-- Write the run to the save directory. Isolated from the campaign save (its own file), so a draft run
-- and the campaign never read or overwrite each other. Returns true, or false plus a message.
function DraftRun.write(run)
    local source = "-- LoveTactics draft run. Generated file.\nreturn "
        .. Save.encode(DraftRun.snapshot(run), 0) .. "\n"
    return love.filesystem.write(DraftRun.FILE, source)
end

-- The saved run, or nil if there is none (or it is unreadable).
function DraftRun.read()
    if not love.filesystem.getInfo(DraftRun.FILE) then return nil end
    local source = love.filesystem.read(DraftRun.FILE)
    if not source then return nil end
    local snap = Save.decode(source)
    if not snap then return nil end
    return DraftRun.restore(snap)
end

function DraftRun.exists()
    return love.filesystem.getInfo(DraftRun.FILE) ~= nil
end

function DraftRun.clear()
    if DraftRun.exists() then love.filesystem.remove(DraftRun.FILE) end
end

return DraftRun
