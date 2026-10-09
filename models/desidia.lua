-- DESIDIA, THE DREAMER: Sloth's general, on floor 10's stair ("Sloth's Bestiary", slice G, 2026-10-04; every rule
-- approved on review). A god asleep under the glacier, so large the board is the lid of her tomb; the only part of
-- her above the ice is a 3x3 sleeping face at the far edge. Desidia is Latin for idleness.
--
-- THE CIRCLE'S WORD IS SLEEP, and the fight is a question the company answers with its own tempo: leave her alone
-- and every turn she sleeps through comes back at once; hit her and she wakes early, with less in hand; stand still
-- and the cold puts you under, and what you dream fights for her.
--
--   THE LONG SLEEP   she opens Dormant (status_dormant) and does nothing while she sleeps. Every round she sleeps
--                    she banks a turn (status_banked, models/bank.lua, no cap), shown on her badge, and marks the
--                    row that turn will sweep (hazard_waking_row) -- the row her foes crowd most as she banks it.
--                    Every attack or ability used anywhere on the board adds a Stir (status_stir); at 10 she wakes
--                    and takes every banked turn at once, each a sweep down its marked row. A blow on her wakes
--                    her early (Dormant's own rule), and the bank is spent the same way.
--   THE DROWSE       at the end of each round every body on the board, either side, that took a turn and did not
--                    move gains Drowsy (status_drowsy); at 3 it falls Asleep.
--   WHAT THE         at the start of each round each of her foes that is asleep dreams, and its nightmare stands up
--   SLEEPERS DREAM   on her side: a shade with that body's face and kit (Summon.copyOf). It lasts until the sleeper
--                    wakes. The Nightmare Lantern, her necromancer's drop, runs the same rule for its bearer.
--   AWAKE, AND       once she has woken and spent her bank she wants to sleep again: any round in which no blow
--   WORSE FOR IT     lands on her, she goes back Dormant and banks from zero.
--
-- A ROUND IS THE STRETCH BETWEEN TWO OF HER OWN TURNS. The engine has no rounds (models/leviathan.lua reads it the
-- same way), and a Dormant body still comes round in the order -- it simply cannot act -- so her turn is the beat
-- every one of these rules is measured on. A body that took no turn in a round is not judged by the Drowse.
--
-- Pure logic, headless-safe. Combat is reached lazily, as every model the combat core calls back into does.

local Status = require("models.status")
local Bank = require("models.bank")

local Desidia = {}

Desidia.DORMANT = "status_dormant"
Desidia.STIR = "status_stir"
Desidia.ROW = "hazard_waking_row"
-- How much Stir wakes her: the review's number.
Desidia.WAKE_AT = 10
-- A sweep's blow, as a multiple of her own Damage (Rude Awakening's +4 is in it: she wakes worse).
Desidia.SWEEP_POWER = 1
Desidia.FOREVER = 9999

local function C() return require("models.combat") end

local function name(u) return (u and u.char and u.char.name) or "Desidia" end

local function state(unit)
    unit.desidia = unit.desidia or { rows = {}, rowHazards = {}, snap = {}, shades = {} }
    return unit.desidia
end
Desidia.state = state

local function dims(combat)
    local a = combat.arena or {}
    local rows = a.rows or (a.tiles and #a.tiles) or 0
    local cols = a.cols or (a.tiles and a.tiles[1] and #a.tiles[1]) or 0
    return cols, rows
end

local function centre(unit)
    return unit.x + math.floor(((unit.w or 1) - 1) / 2), unit.y + math.floor(((unit.h or 1) - 1) / 2)
end

-- Is `u` a body the board's rules are about: alive, standing on a tile, and taking turns?
local function onBoard(u)
    return u and u.alive and not C().isOffTile(u) and not u.timeless
end

function Desidia.isAsleep(unit) return state(unit).asleep == true end

-- ------------------------------------------------------------------------------------------ the bell

-- SEATED AT THE FAR EDGE, the face above the ice: the edge farther from where her foes stand, centred along it.
-- Only a body her own size is moved -- a general worn as somebody else's form (the Many Faced One) keeps its tile
-- and its footprint. The Hollow Crown's throne is her size and is seated by this same call (models/hollow_crown.lua).
function Desidia.seat(combat, unit)
    if (unit.w or 1) < 3 then return end
    local cols, rows = dims(combat)
    local sum, n = 0, 0
    for _, u in ipairs(combat.units or {}) do
        if onBoard(u) and u.side ~= unit.side then sum, n = sum + u.y, n + 1 end
    end
    local meanY = n > 0 and sum / n or rows
    local y = (meanY > rows / 2) and 1 or math.max(1, rows - unit.h + 1)
    local x = math.max(1, math.floor((cols - unit.w) / 2) + 1)
    if x == unit.x and y == unit.y then return end
    local Combat = C()
    if not Combat.footprintFree(combat, unit.w, unit.h, x, y, unit) then
        x, y = Combat.openBlockNear(combat, x, y, unit.w, unit.h, { ignore = unit, radius = 4 })
    end
    if x then Combat.teleportUnit(combat, unit, x, y, { silent = true }) end
end

-- The opening bell: seated, asleep, and the board's stillness first taken (the Drowse's baseline).
function Desidia.open(combat, unit)
    Desidia.seat(combat, unit)
    Desidia.sleep(combat, unit)
end

-- ------------------------------------------------------------------------------------------ the sleep

function Desidia.sleep(combat, unit)
    local st = state(unit)
    st.asleep = true
    st.struck = false
    Status.remove(combat, unit, Desidia.STIR)
    if not Status.has(unit, Desidia.DORMANT) then
        Status.apply(combat, unit, Desidia.DORMANT, { applier = unit })
    end
end

-- The row a banked turn will sweep: the one her foes crowd most right now, ties to the row nearest her face.
function Desidia.pickRow(combat, unit)
    local _, rows = dims(combat)
    local count = {}
    for _, u in ipairs(combat.units or {}) do
        if onBoard(u) and u.side ~= unit.side then
            local seen = {}
            for _, c in ipairs(C().unitCells(u)) do
                if not seen[c.y] then seen[c.y] = true; count[c.y] = (count[c.y] or 0) + 1 end
            end
        end
    end
    local _, cy = centre(unit)
    local best, bestN
    for y = 1, rows do
        local k = count[y] or 0
        if k > 0 and (not bestN or k > bestN
            or (k == bestN and math.abs(y - cy) < math.abs(best - cy))) then
            best, bestN = y, k
        end
    end
    return best
end

-- BANK A TURN, and mark its row. The marks are laid unowned (owned ground walks with its owner), one zone a tile;
-- a row marked twice is one row on the board and two sweeps in the bank.
function Desidia.bank(combat, unit)
    local Hazard = require("models.hazard")
    local st = state(unit)
    Bank.add(combat, unit, 1, nil)
    local y = Desidia.pickRow(combat, unit)
    st.rows[#st.rows + 1] = y or false
    if y then
        local cols = dims(combat)
        for x = 1, cols do
            local h = Hazard.place(combat, x, y, Desidia.ROW, { side = unit.side, duration = Desidia.FOREVER })
            if h then st.rowHazards[#st.rowHazards + 1] = h end
        end
    end
    C().logEvent(combat, "status", string.format("%s sleeps on, and the cold gathers%s.", name(unit),
        y and (" over row " .. y) or ""), unit)
    return y
end

local function liftRows(combat, unit)
    local Hazard = require("models.hazard")
    local st = state(unit)
    for _, h in ipairs(st.rowHazards) do Hazard.consume(combat, h) end
    st.rowHazards = {}
end

-- ONE SWEEP: every foe with a cell in row `y` takes her blow.
function Desidia.sweep(combat, unit, y)
    local Combat = C()
    local amount = math.max(1, math.floor(Combat.flatStat(unit, "damage") * Desidia.SWEEP_POWER))
    local hit = {}
    for _, u in ipairs(combat.units or {}) do
        if onBoard(u) and u.side ~= unit.side then
            for _, c in ipairs(Combat.unitCells(u)) do
                if c.y == y then hit[#hit + 1] = u; break end
            end
        end
    end
    Combat.logEvent(combat, "action", string.format("%s sweeps row %d.", name(unit), y), unit)
    for _, u in ipairs(hit) do
        if u.alive then
            Combat.dealFlatDamage(combat, u, amount, { "physical", "impact", "ice" }, "Desidia's sweep", unit)
        end
    end
    return hit
end

-- SHE WAKES: Dormant off (its Rude Awakening on), the Stir gone, and every banked turn taken at once -- a sweep down
-- each marked row, in the order they were banked. `cause` is "blow" or "stir".
function Desidia.wake(combat, unit, cause)
    local st = state(unit)
    if st.waking or not st.asleep then return 0 end
    st.waking = true
    st.asleep = false
    st.woken = true
    if cause == "blow" then st.struck = true end
    if Status.has(unit, Desidia.DORMANT) then Status.remove(combat, unit, Desidia.DORMANT) end
    Status.remove(combat, unit, Desidia.STIR)
    C().logEvent(combat, "action", string.format("%s opens her eyes.", name(unit)), unit)
    local n = Bank.spend(combat, unit)
    local rows = st.rows
    st.rows = {}
    liftRows(combat, unit)
    for i = 1, n do
        local y = rows[i]
        if y and unit.alive then Desidia.sweep(combat, unit, y) end
    end
    st.waking = false
    return n
end

-- A STIR: an attack or an ability used anywhere on the board, while she sleeps.
function Desidia.stir(combat, unit)
    if not (unit.alive and Desidia.isAsleep(unit)) then return end
    Status.apply(combat, unit, Desidia.STIR, { magnitude = 1, applier = unit })
    if Status.stacksOf(unit, Desidia.STIR) >= Desidia.WAKE_AT then Desidia.wake(combat, unit, "stir") end
end

-- A wound landed on her. Asleep, it wakes her (Dormant's own rule; the bank is spent here). Awake, it is the blow
-- that keeps her up this round.
function Desidia.struck(combat, unit, amount)
    if (amount or 0) <= 0 then return end
    local st = state(unit)
    st.struck = true
    if st.asleep then Desidia.wake(combat, unit, "blow") end
end

-- The end of her own turn. Asleep: a turn banked. Awake, having woken once: a round with no blow on her puts her
-- back to sleep, banking from zero.
function Desidia.turnEnd(combat, unit)
    local st = state(unit)
    if st.asleep then
        Desidia.bank(combat, unit)
    elseif not st.struck then
        C().logEvent(combat, "status", string.format("Nothing touches %s, and she goes back to sleep.", name(unit)),
            unit)
        Desidia.sleep(combat, unit)
    end
    st.struck = false
end

function Desidia.onDeath(combat, unit)
    liftRows(combat, unit)
    state(unit).rows = {}
end

-- ---------------------------------------------------------------------------------------------- the Drowse

local function stillness(u)
    local Combat = C()
    return Combat.tallyCount(u, "tilesMoved") + Combat.tallyCount(u, "tilesBlinked"), Combat.tallyCount(u, "turnTaken")
end

-- Take the board's stillness, so the next round is measured from here.
function Desidia.snapshot(combat, unit)
    local st = state(unit)
    st.snap = {}
    for _, u in ipairs(combat.units or {}) do
        if onBoard(u) and u ~= unit then
            local moved, turns = stillness(u)
            st.snap[u] = { moved = moved, turns = turns }
        end
    end
end

-- THE DROWSE, at the end of her round: every body that took a turn since the last one and moved on none of them
-- gains Drowsy. Either side; never her.
function Desidia.drowse(combat, unit)
    local st = state(unit)
    local drowsed = {}
    for _, u in ipairs(combat.units or {}) do
        if onBoard(u) and u ~= unit then
            local was = st.snap[u]
            local moved, turns = stillness(u)
            if was and turns > was.turns and moved == was.moved then
                Status.apply(combat, u, "status_drowsy", { applier = unit })
                drowsed[#drowsed + 1] = u
            end
        end
    end
    Desidia.snapshot(combat, unit)
    return drowsed
end

-- ------------------------------------------------------------------------------- what the sleepers dream

-- At the start of the bearer's round: every foe of its asleep, with no nightmare of this bearer's standing, dreams
-- one up on the bearer's side, set down as near the bearer as the ground allows. A shade is never dreamed of again.
function Desidia.dream(combat, bearer)
    local Combat = C()
    local st = state(bearer)
    local have = {}
    for _, e in ipairs(st.shades) do
        if e.shade.alive then have[e.sleeper] = true end
    end
    local made = {}
    local cx, cy = centre(bearer)
    for _, u in ipairs(combat.units or {}) do
        if onBoard(u) and u.side ~= bearer.side and not u.shadeOf and not have[u]
            and Status.has(u, "status_sleep") then
            local x, y = Combat.openBlockNear(combat, cx, cy, 1, 1, { radius = 5 })
            if x then
                local shade = require("models.summon").copyOf(combat, bearer, u, x, y, {})
                if shade and shade.alive then
                    shade.shadeOf = u
                    shade.char.name = ((u.char and u.char.name) or "Somebody") .. "'s Nightmare"
                    st.shades[#st.shades + 1] = { shade = shade, sleeper = u }
                    made[#made + 1] = shade
                end
            end
        end
    end
    return made
end

-- A shade whose sleeper is awake (or gone) goes with the dream.
function Desidia.reapShades(combat, bearer)
    local st = state(bearer)
    local keep = {}
    for _, e in ipairs(st.shades) do
        if e.shade.alive then
            if e.sleeper.alive and Status.has(e.sleeper, "status_sleep") then
                keep[#keep + 1] = e
            else
                C().dismiss(combat, e.shade, string.format("%s fades as its dreamer wakes.",
                    (e.shade.char and e.shade.char.name) or "The nightmare"))
            end
        end
    end
    st.shades = keep
end

return Desidia
