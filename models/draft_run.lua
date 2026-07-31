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

-- The marching FORMATION the fielded party stands in: a COLS x ROWS grid (row 1 is the front line,
-- nearest the enemy), the same shape the campaign uses (Player.FORMATION_COLS/ROWS) and the same one
-- models/arena.lua seats a party into. Duplicated here (not required) to keep this module player-free,
-- exactly as PARTY_MAX is. The grid holds up to PARTY_MAX units among its cells -- front/back is a
-- tactical choice, so there are more cells than fielders. Unlike the campaign's id-keyed formation,
-- draft seats units by INSTANCE (run.formation[cell] = char), because two un-merged duplicates share an
-- id and an id-keyed slot would collide.
DraftRun.FORMATION_COLS = 4
DraftRun.FORMATION_ROWS = 2
DraftRun.FORMATION_CELLS = DraftRun.FORMATION_COLS * DraftRun.FORMATION_ROWS

-- How many units the BENCH may hold at once: reserves and merge fodder waiting behind the fielded
-- formation. (The fielded four live in run.formation, not here.)
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
        formation = {}, -- cell (1..FORMATION_CELLS) -> fielded char instance (sparse; <= PARTY_MAX filled)
        bench = {},   -- reserve / merge-fodder character instances behind the formation
        stash = {},   -- unequipped item instances (bought gear, and whatever a merge could not absorb)
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

-- Roll the round over: bump the counter, refresh the budget, mend the company back to full, and
-- restock the consumables the fight just drank (see the mending and restocking sections -- a draft
-- round is a whole match, so neither wounds nor a drained flask carry into the next one).
-- Called by recordResult after a non-terminal battle; the shop roll is the state layer's to trigger
-- (DraftShop.roll), because only it knows whether the player froze anything.
function DraftRun.advanceRound(run)
    run.round = (run.round or 1) + 1
    run.gold = DraftRun.roundBudget(run.round)
    DraftRun.restoreParty(run)
    DraftRun.refillConsumables(run)
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
-- The formation grid + the bench
-- ---------------------------------------------------------------------------
--
-- Two homes for a drafted unit: the FORMATION (run.formation, cell -> char, the up-to-four that take
-- the field, seated by front/back row) and the BENCH (run.bench, an ordered list of reserves and merge
-- fodder). A drafted unit auto-fills the formation until it holds PARTY_MAX, then spills to the bench;
-- the arrange screen (states/draft.lua) moves units between the two by drag.

-- Cell (1..FORMATION_CELLS) <-> (col, row), row-major: cells 1..COLS are the FRONT row, the rest step
-- back. Row 1 faces the enemy (models/arena.lua seats it there).
function DraftRun.cellToColRow(cell)
    local cols = DraftRun.FORMATION_COLS
    return ((cell - 1) % cols) + 1, math.floor((cell - 1) / cols) + 1
end

function DraftRun.colRowToCell(col, row)
    return (row - 1) * DraftRun.FORMATION_COLS + col
end

-- How many units currently stand in the formation.
function DraftRun.formationCount(run)
    local n = 0
    for cell = 1, DraftRun.FORMATION_CELLS do
        if run.formation and run.formation[cell] then n = n + 1 end
    end
    return n
end

function DraftRun.formationFull(run)
    return DraftRun.formationCount(run) >= DraftRun.PARTY_MAX
end

-- The first empty formation cell (front row left-to-right, then back), or nil when the formation
-- already fields PARTY_MAX. Where a freshly drafted unit lands.
function DraftRun.firstFreeCell(run)
    if DraftRun.formationFull(run) then return nil end
    for cell = 1, DraftRun.FORMATION_CELLS do
        if not (run.formation and run.formation[cell]) then return cell end
    end
    return nil
end

-- The cell `char` stands on in the formation, or nil if it is not fielded.
function DraftRun.cellOf(run, char)
    for cell = 1, DraftRun.FORMATION_CELLS do
        if run.formation and run.formation[cell] == char then return cell end
    end
    return nil
end

-- Is `char` on the bench?
local function benchIndexOf(run, char)
    for i, c in ipairs(run.bench or {}) do
        if c == char then return i end
    end
    return nil
end

function DraftRun.benchFull(run)
    return #(run.bench or {}) >= DraftRun.BENCH_MAX
end

-- No room ANYWHERE for another drafted unit: the formation is full AND so is the bench. What the shop
-- checks before selling a unit (DraftShop.buyUnit) -- a drafted unit auto-fills the formation first, so
-- a full bench alone no longer means the roster is full.
function DraftRun.rosterFull(run)
    return DraftRun.formationFull(run) and DraftRun.benchFull(run)
end

-- Draft a live character instance: auto-fill the first empty formation cell, else spill to the bench.
-- Returns true, or false if BOTH the formation is full AND the bench is full (the caller should have
-- checked benchFull/formationFull and refunded/refused). Does NOT auto-merge -- combining duplicates is
-- an explicit player action (DraftRun.mergeUnit).
function DraftRun.addUnit(run, char)
    run.formation = run.formation or {}
    local cell = DraftRun.firstFreeCell(run)
    if cell then run.formation[cell] = char return true end
    if DraftRun.benchFull(run) then return false end
    run.bench = run.bench or {}
    run.bench[#run.bench + 1] = char
    return true
end

-- The units that take the field, in cell order (front row first). Returns a fresh list of instances;
-- DraftRun.formationSlots returns the parallel {col,row} list for seating (models/arena.lua).
function DraftRun.party(run)
    local party = {}
    for cell = 1, DraftRun.FORMATION_CELLS do
        local c = run.formation and run.formation[cell]
        if c then party[#party + 1] = c end
    end
    return party
end

-- Every unit the run holds -- fielded first, then the bench -- through `fn`. The one walker for
-- anything that is true of the whole company (mending it between rounds, restocking its flasks).
function DraftRun.eachChar(run, fn)
    for _, char in ipairs(DraftRun.party(run)) do fn(char) end
    for _, char in ipairs(run.bench or {}) do fn(char) end
end

-- One {col,row} per fielded unit, parallel to DraftRun.party -- the marching slots the battle seats the
-- party into (states/battle.lua -> models/arena.lua). Instance-ordered, so a duplicate id can't confuse
-- which unit sits where.
function DraftRun.formationSlots(run)
    local slots = {}
    for cell = 1, DraftRun.FORMATION_CELLS do
        if run.formation and run.formation[cell] then
            local col, row = DraftRun.cellToColRow(cell)
            slots[#slots + 1] = { col = col, row = row }
        end
    end
    return slots
end

-- Move `char` (from wherever it is -- a formation cell, the bench, or freshly drafted) onto formation
-- `cell`, swapping with whoever is there. The swap keeps the fielded count honest:
--   * from a formation cell: a plain swap of the two cells (the other unit takes the vacated cell).
--   * from the bench onto an EMPTY cell: only if the formation isn't already full (no fifth fielder).
--   * from the bench onto an OCCUPIED cell: a swap -- the occupant is sent to the bench.
-- Returns true on success, or false (nothing moved) when the move would over-fill the formation.
function DraftRun.placeInCell(run, char, cell)
    if not char or not cell then return false end
    run.formation = run.formation or {}
    local occupant = run.formation[cell]
    if occupant == char then return true end

    local fromCell = DraftRun.cellOf(run, char)
    if fromCell then
        run.formation[fromCell] = occupant -- may be nil (char simply moves) or a swap
        run.formation[cell] = char
        return true
    end

    -- Coming from the bench (or brand new): field it, benching whoever it displaces.
    local bi = benchIndexOf(run, char)
    if not occupant and DraftRun.formationFull(run) then return false end
    if bi then table.remove(run.bench, bi) end
    run.formation[cell] = char
    if occupant then
        run.bench = run.bench or {}
        run.bench[#run.bench + 1] = occupant
    end
    return true
end

-- Send a fielded unit back to the bench (a demotion, freeing its cell). Returns true, or false if the
-- bench is full (nothing moves -- the unit stays fielded). A no-op for a unit already on the bench.
function DraftRun.benchUnit(run, char)
    local cell = DraftRun.cellOf(run, char)
    if not cell then return false end
    if DraftRun.benchFull(run) then return false end
    run.formation[cell] = nil
    run.bench = run.bench or {}
    run.bench[#run.bench + 1] = char
    return true
end

-- Field a benched unit into the first free formation cell. Returns true, or false if the formation is
-- already full (nothing moves). A no-op for a unit already fielded.
function DraftRun.fieldUnit(run, char)
    if DraftRun.cellOf(run, char) then return true end
    local cell = DraftRun.firstFreeCell(run)
    if not cell then return false end
    return DraftRun.placeInCell(run, char, cell)
end

-- Remove `char` from wherever it lives -- a formation cell OR the bench (a sale, or the consumed half of
-- a merge). Returns true if it was found.
function DraftRun.removeUnit(run, char)
    local cell = DraftRun.cellOf(run, char)
    if cell then run.formation[cell] = nil return true end
    local bi = benchIndexOf(run, char)
    if bi then table.remove(run.bench, bi) return true end
    return false
end

-- ---------------------------------------------------------------------------
-- Merging duplicates
-- ---------------------------------------------------------------------------

-- Could a unit of blueprint `id` combine INTO `target`? The merge rule stated over an ID rather than a
-- live instance, so a caller can ask BEFORE it has a body to offer -- what the store needs to decide
-- whether dragging a card onto a unit buys-and-combines (DraftShop.buyUnitInto).
function DraftRun.canMergeIdInto(id, target)
    if not id or not target or id ~= target.id then return false end
    return (target.level or 1) < DraftRun.MAX_UNIT_LEVEL
end

-- Two bench units combine when they are the same blueprint and the one being KEPT is below the level
-- ceiling. (Different characters never merge; two maxed copies have nowhere to grow.)
function DraftRun.canMergeUnits(source, target)
    if not source or source == target then return false end
    return DraftRun.canMergeIdInto(source.id, target)
end

-- Combine `source` INTO `target`: bump the kept unit one growth level (the confirmed reuse of
-- models/growth.lua -- a merge grows a unit exactly as a prestige level-up would, reading the class
-- tally it was built with), cascade the fodder's gear into the kept unit's grid, and drop the source.
--
-- THE MERGE RUNS AT BOTH LEVELS AT ONCE. Fodder is the same blueprint as its target by definition, so
-- its grid is mostly gear the target already holds -- above all the chassis signatures, which every
-- bought duplicate carries a fresh copy of. Stashing those made the mode's most common action
-- (buy a duplicate, drag it on) mint one or two junk copies of the target's own weapon every time.
-- So each piece is offered to the kept unit's grid first: a copy of something already on the grid merges
-- IN PLACE, one level above the better of the two, in the cell it already occupied. Combining duplicates
-- upgrades the gear they share -- which is the point of the mode, where gear is the draft. It keeps
-- paying on the third and fourth duplicate too; the levels of the two copies do not have to line up
-- (DraftRun.canMergeItems).
--
-- Anything that does NOT match is the player's own distinct choice, and still goes to the stash for
-- them to re-slot deliberately (grid slots, not gold, are the binding constraint -- see
-- models/draft_match.lua -- so nothing is auto-equipped into a free cell). A bound relic that finds no
-- match goes with the body: Item.isBound refuses to let it be stowed, and there is nowhere else.
--
-- Returns { unit, fromLevel, toLevel, upgraded = { merged items }, stashed = n } or nil + reason.
function DraftRun.mergeUnit(run, source, target)
    if not DraftRun.canMergeUnits(source, target) then return nil, "cannot merge" end

    local fromLevel = target.level or 1
    Growth.resolve(target, math.min(fromLevel + 1, DraftRun.MAX_UNIT_LEVEL))

    local upgraded, stashed = {}, 0
    for cell = 1, Character.MAX_INVENTORY do
        local item = source.inventory and source.inventory[cell]
        if item then
            local merged = DraftRun.mergeItemInto(target, item)
            if merged then
                upgraded[#upgraded + 1] = merged
            elseif not Item.isBound(item) then
                run.stash = run.stash or {}
                run.stash[#run.stash + 1] = item
                stashed = stashed + 1
            end
        end
    end

    DraftRun.removeUnit(run, source)
    return { unit = target, fromLevel = fromLevel, toLevel = target.level, upgraded = upgraded, stashed = stashed }
end

-- Two copies of the same blueprint combine, as long as the better of the two is below the item ceiling.
-- THEIR LEVELS NEED NOT MATCH: a +1 absorbs a fresh +0 and becomes +2. Counting copies is what puts gear
-- on the same footing as bodies, where every duplicate is flatly one growth level (DraftRun.mergeUnit).
--
-- The rule used to demand EQUAL levels, which made item upgrades a binary tree: a +2 took four copies,
-- a +3 eight, and Item.MAX_LEVEL = 10 a thousand. Merging the same character a second time then upgraded
-- its signature not at all -- the fodder's fresh +0 could no longer see the +1 the first merge had made,
-- so it fell through to the stash as a junk copy of the weapon the unit was already holding, which is
-- the exact litter the cascade in mergeUnit exists to prevent. Duplicates past the second have to keep
-- paying, or the mode's most common purchase stops being worth making.
function DraftRun.canMergeItems(a, b)
    if not a or not b or a == b then return false end
    if a.id ~= b.id then return false end
    return math.max(a.level or 0, b.level or 0) < Item.MAX_LEVEL
end

-- Combine two copies into one a level above the BETTER of them: returns a FRESH instance at
-- max(level) + 1, carrying the combined stack count (so merging two stacks of a consumable keeps the
-- count). Taking the max rather than the target's own level means a forged piece spent as fodder is
-- never quietly downgraded -- a +3 poured into a +0 yields a +4, one better than either half alone.
-- Returns nil if the two cannot merge. The caller swaps the result into the target cell and discards
-- the source.
function DraftRun.mergeItems(a, b)
    if not DraftRun.canMergeItems(a, b) then return nil end
    local quantity = (a.quantity or 1) + (b.quantity or 1)
    local level = math.min(math.max(a.level or 0, b.level or 0) + 1, Item.MAX_LEVEL)
    return Item.instantiate(a.id, quantity, level)
end

-- The cell on `char`'s grid holding an item that `item` would combine with, or nil. The question every
-- caller that has an item in hand and a body to aim it at wants answered: a merge fodder's gear, a
-- stash card mid-drag, a store card dropped straight onto a unit.
--
-- `item` is read for nothing but `id` and `level`, so a store ENTRY answers it as well as an instance --
-- the screen can ring a unit green while the card is still moving, before there is anything bought to
-- offer it. (The same trick DraftRun.canMergeIdInto plays for units, for the same reason.)
--
-- Now that levels no longer have to match (see canMergeItems), a grid can hold two eligible copies, so
-- the choice needs a rule: the HIGHEST one wins, ties going to the earlier cell. Highest is simply worth
-- the most -- feeding a +0 to a +3 leaves the player a +4 and their +0, where the other order leaves a
-- +1 and their +3 -- and it keeps a build's one forged centrepiece climbing instead of spreading the
-- gain thin across copies.
function DraftRun.mergeSlotFor(char, item)
    if not (char and char.inventory and item) then return nil end
    local best, bestLevel
    for cell = 1, Character.MAX_INVENTORY do
        local held = char.inventory[cell]
        if DraftRun.canMergeItems(held, item) and (not best or (held.level or 0) > bestLevel) then
            best, bestLevel = cell, held.level or 0
        end
    end
    return best
end

-- Combine `item` into `char`'s matching cell IN PLACE, and return the merged item + its cell (or nil
-- when nothing on the grid matches). In place is the whole point: the grid is an adjacency surface
-- (auras reach the eight neighbours, Character.adjacentIndices), so an upgrade that relocated the piece
-- would silently rearrange a build the player laid out. It is also what lets a BOUND relic upgrade --
-- Item.isBound forbids moving a piece, never levelling one where it sits.
--
-- Only the target's GRID is ever scanned, so two loose items never merge with each other behind the
-- caller's back -- a property worth keeping now that levels no longer have to match, because far more
-- pairs are eligible than used to be. A cell CAN take a second piece in the same pass (a fodder holding
-- three swords delivers three levels), which is the same total the player would get slotting them from
-- the stash one at a time; the merge just does not make them do it by hand.
function DraftRun.mergeItemInto(char, item)
    local cell = DraftRun.mergeSlotFor(char, item)
    if not cell then return nil end
    local merged = DraftRun.mergeItems(char.inventory[cell], item)
    if not merged then return nil end
    char.inventory[cell] = merged
    return merged, cell
end

-- ---------------------------------------------------------------------------
-- Mending: the company comes back whole every round
-- ---------------------------------------------------------------------------
--
-- Same reasoning as the consumable restock below. A campaign quest is a chain of fights and attrition
-- across them is the point (Player.restore mends only at the hub); a draft ROUND is a whole match, and
-- the next one is a fresh match against a bot synthesized whole (models/draft_match.lua). Carrying
-- wounds forward would hand that bot a compounding edge nobody drafted, and a unit that fell would be
-- dead weight forever -- health persists on the reused instance (models/combat.lua's between-battle
-- policy), so a felled unit's pool sits at zero and it would walk into the next round already down.
--
-- So every pool -- health, mana, stamina -- comes back full at the rollover, on fielders and reserves
-- alike (a benched unit is next round's team). Combat.new already refills stamina and drops stale
-- reservations at the bell for every side, so this is health and mana in practice; running the whole
-- RESOURCE_STATS list keeps it correct if a fourth pool is ever added.
function DraftRun.restoreParty(run)
    DraftRun.eachChar(run, function(char)
        for _, stat in ipairs(Character.RESOURCE_STATS) do
            local resource = char.stats and char.stats[stat]
            if type(resource) == "table" then resource.current = resource.max end
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Consumables: spent in the fight, restocked for the next round
-- ---------------------------------------------------------------------------
--
-- A draft round is a whole match, not a leg of a campaign quest, so the campaign's attrition rule --
-- a flask drunk is a flask gone until you buy another -- does not belong here. Under it a consumable
-- would be a full-price purchase that works once, and the house bot, which is synthesized WHOLE every
-- round (models/draft_match.lua), would carry a free edge from round two on. So every stack the party
-- marches out with comes back full when the round rolls over, and a potion is a standing part of a
-- build rather than a one-round rental.
--
-- Two halves, because "full" has to be remembered BEFORE a fight spends it: stockConsumables stamps
-- each stack's marching count as the battle launches, refillConsumables pours it back at the rollover.
-- The stamp is taken at the gate rather than at purchase deliberately -- every way an item reaches a
-- unit (bought, merged into a fresh instance, pulled out of the stash, authored on a chassis) marches
-- through that one moment, so none of those paths has to remember to stock anything.

-- Run every item instance the run holds -- the fielded grids, the bench's grids, and the loose stash --
-- through `fn`. The stash is included because a depleted stack can be stowed and re-equipped between
-- rounds, and it would be a strange rule that restocked it only while it sat on a unit.
local function eachRunItem(run, fn)
    DraftRun.eachChar(run, function(char)
        for _, item in ipairs(Character.eachItem(char)) do fn(item) end
    end)
    for _, item in ipairs(run.stash or {}) do fn(item) end
end

-- Record what every consumable stack holds as the party marches out; `item.stock` is the count
-- refillConsumables restores it to. Called by the state layer at the moment it switches to the battle
-- (states/draft.lua), which is the last instant the counts are untouched by the fight.
function DraftRun.stockConsumables(run)
    eachRunItem(run, function(item)
        if Item.isStackable(item) then item.stock = item.quantity or 1 end
    end)
end

-- Pour every consumable stack back up to its marching count. A stack with no stamp (bought after the
-- last fight, or reloaded from disk) is left exactly as it is -- it was never spent.
function DraftRun.refillConsumables(run)
    eachRunItem(run, function(item)
        if Item.isStackable(item) and item.stock then
            item.quantity = math.max(item.quantity or 0, item.stock)
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Persistence (snapshot <-> plain data; disk)
-- ---------------------------------------------------------------------------

-- A run as plain, scalar-only data. Formation, bench and stash reuse the save file's character/item
-- snapshot, so a leveled, geared unit reloads exactly (Save.snapshotCharacter carries level, class
-- tally, growth and grid). The formation is written as { cell, char } pairs so each fielder reloads on
-- the same tile. Safe to Save.encode -- no functions, no love objects.
function DraftRun.snapshot(run)
    local formation = {}
    for cell = 1, DraftRun.FORMATION_CELLS do
        local c = run.formation and run.formation[cell]
        if c then formation[#formation + 1] = { cell = cell, char = Save.snapshotCharacter(c) } end
    end
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
        formation = formation, bench = bench, stash = stash,
    }
end

-- Rebuild a run from a snapshot. Unknown content is dropped the way a save drops it (a removed
-- character or item leaves the rest intact) -- a run is the player's own progress, worth salvaging in
-- part, unlike a build handed over whole. Returns the run, or nil if the snapshot is junk.
--
-- A PRE-FORMATION save has no `formation` field, only a flat `bench` list of every drafted unit: seat
-- those the same way drafting them would (auto-fill the formation, spill to the bench) so an old run
-- upgrades cleanly rather than fielding nobody.
function DraftRun.restore(snap)
    if type(snap) ~= "table" then return nil end
    local stash = {}
    for _, itemSnap in ipairs(snap.stash or {}) do
        if Save.known(Item.defs, itemSnap.id) then
            stash[#stash + 1] = Item.instantiate(itemSnap.id, itemSnap.quantity, itemSnap.level)
        end
    end
    local run = {
        round = snap.round or 1,
        wins = snap.wins or 0,
        losses = snap.losses or 0,
        gold = snap.gold or DraftRun.roundBudget(snap.round or 1),
        rngSeed = snap.rngSeed or os.time(),
        formation = {},
        bench = {},
        stash = stash,
        shop = nil, -- a fresh roll is cheaper than serializing one, and never stale
    }

    if snap.formation then
        -- New shape: formation cells restored to their exact tiles, then the bench in order.
        for _, entry in ipairs(snap.formation) do
            local cs = entry.char
            if entry.cell and cs and Save.known(Character.defs, cs.id) then
                run.formation[entry.cell] = Save.restoreCharacter(cs)
            end
        end
        for _, charSnap in ipairs(snap.bench or {}) do
            if Save.known(Character.defs, charSnap.id) then
                run.bench[#run.bench + 1] = Save.restoreCharacter(charSnap)
            end
        end
    else
        -- Legacy shape: one flat bench of every drafted unit -- re-draft each so the first four field.
        for _, charSnap in ipairs(snap.bench or {}) do
            if Save.known(Character.defs, charSnap.id) then
                DraftRun.addUnit(run, Save.restoreCharacter(charSnap))
            end
        end
    end
    return run
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
