-- LEVIATHAN: Envy's mini boss, on floor 11's stair (reviewed 2026-10-01..03, "Envy's Bestiary", rows lv_body,
-- lv_under, lv_rise, lv_sea and lv_tail). The demon prince of Envy in Binsfeld's classification, a sea-serpent
-- under a sea of sand. A mini boss teaches its general's rule a floor early; Envy's general wears other bosses,
-- which nothing can foreshadow, so Leviathan teaches the circle's own word instead -- THE FAIREST
-- (models/fairest.lua): it rises under whatever shines.
--
-- THE CYCLE, one of its turns at a time. There are no rounds in this engine, so "a round" is the stretch between
-- two of its own turns, the same reading the Sphinx's riddle takes.
--
--   UNDER     between surfacings it wears Underground (data/status/status_underground.lua, the Delve's own
--             status): it cannot be targeted or harmed, and it takes no action (AI.preempt holds it).
--   THE MARK  at the end of a turn it spends Underground it marks the 3x3 under the Fairest of the company. The
--             mark is a Ripple on the sand (hazard_ripple), so where it will rise is on the board a turn early.
--   UP        at the start of its next turn it surfaces there: every foe in the 3x3 takes a heavy blow,
--             everyone standing in it is shoved out of it, and it comes up in the hole. It acts that turn, and
--             stays up until its NEXT turn opens -- the round in which it can be hit -- and then dives again.
--   THE SEA   every 3x3 it comes up through is quicksand for the rest of the fight (hazard_quicksand, which
--             Mires). The board drowns as the fight goes on. Its own sand does not hold it (`groundproof`).
--   THE TAIL  below half health its tail rises too: at the end of EVERY turn it marks a second 3x3 under the
--             next-Fairest, which erupts at the start of its next turn exactly as the head does, without the
--             body coming up.
--
-- THE COUNTERPLAY IS WHERE THE BLESSINGS SIT. You choose where it rises by choosing who holds them; walk the
-- Fairest out of the mark and hit the body hard in the round it is up. The Glass-Motes it fights over strip
-- blessings, so they move the mark.
--
-- One function, Leviathan.erupt, is the surfacing's blast, and the Undertow (its elementalist drop) calls the
-- same one through a cast's own helpers, so the drop and the boss cannot disagree about what an eruption is.
--
-- Pure logic, headless-safe. Combat is reached lazily, as every model the combat core calls back into does.

local Status = require("models.status")
local Fairest = require("models.fairest")

local Leviathan = {}

Leviathan.UNDER = "status_underground"
Leviathan.RIPPLE = "hazard_ripple"
Leviathan.SAND = "hazard_quicksand"
-- How long a dive holds between refreshes. Three of its turns: refreshed at the end of every turn it spends under
-- and lifted the moment it rises, so the badge never has to quote an infinite hourglass. A turn the clock pushes
-- past the hold finds it up early, and it simply dives again as that turn opens (Leviathan.turnStart).
Leviathan.UNDER_TICKS = 15
-- "For the rest of the fight", in the zone clock's own units (Bind Spirit's 9999, ability_bind_spirit.lua).
Leviathan.SAND_TICKS = 9999
-- The surfacing's blow, as a multiple of its own Damage: heavy, and mitigated like any blow.
Leviathan.SURFACE_POWER = 2
-- Its tail rises below this share of its health.
Leviathan.TAIL_AT = 0.5

local function C() return require("models.combat") end

local function name(u) return (u and u.char and u.char.name) or "Leviathan" end

local function state(unit)
    unit.leviathan = unit.leviathan or { tails = {}, ripples = {} }
    return unit.leviathan
end

function Leviathan.isLeviathan(unit)
    return unit ~= nil and require("models.trait").flag(unit, "underTheSand") ~= nil
end

function Leviathan.isUnder(unit) return Status.has(unit, Leviathan.UNDER) end

-- Is any cell of `u`'s body inside the 3x3 centred on (cx, cy)?
local function inArea(u, cx, cy)
    for _, c in ipairs(C().unitCells(u)) do
        if math.abs(c.x - cx) <= 1 and math.abs(c.y - cy) <= 1 then return true end
    end
    return false
end

-- Every living body standing in the 3x3, `except` excepted, outermost first so a shove out of the area runs into
-- ground the body beyond it has already left. A stable tiebreak, because seeds must replay.
function Leviathan.caught(combat, cx, cy, except)
    local out = {}
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u ~= except and not C().isOffTile(u) and inArea(u, cx, cy) then out[#out + 1] = u end
    end
    table.sort(out, function(a, b)
        local da = math.max(math.abs(a.x - cx), math.abs(a.y - cy))
        local db = math.max(math.abs(b.x - cx), math.abs(b.y - cy))
        if da ~= db then return da > db end
        return (a.x * 1000 + a.y) < (b.x * 1000 + b.y)
    end)
    return out
end

local function sign(n) return (n > 0 and 1) or (n < 0 and -1) or 0 end

-- How far `u` must travel along (dx, dy) to leave the 3x3, and where it lands.
local function exitAlong(u, cx, cy, dx, dy)
    local n = 0
    local probe = { x = u.x, y = u.y, w = u.w, h = u.h }
    repeat
        n = n + 1
        probe.x, probe.y = u.x + dx * n, u.y + dy * n
    until not inArea(probe, cx, cy) or n >= 4
    return { x = probe.x, y = probe.y }, n
end

-- Is every step of that lane open ground the body could stand on?
local function laneClear(combat, u, dx, dy, n)
    if not combat then return true end
    local Combat = C()
    for i = 1, n do
        if not Combat.footprintShovable(combat, u.w or 1, u.h or 1, u.x + dx * i, u.y + dy * i, u) then return false end
    end
    return true
end

-- Where a body standing in the 3x3 is shoved to leave it. Straight out along the axis it is furthest along, and
-- far enough that no cell of it is left inside; a body on the mark's heart goes out away from `from` (the
-- eruption's source). When that lane is barred -- a body, a wall, the board's edge -- the next lane that is open
-- is taken instead (the far side of the same axis last), and with none open the shove runs the first lane and
-- slams into whatever bars it, as any shove does.
function Leviathan.exitFor(u, cx, cy, from, combat)
    local ox, oy = u.x - cx, u.y - cy
    local lanes = {}
    local function add(dx, dy)
        for _, l in ipairs(lanes) do if l[1] == dx and l[2] == dy then return end end
        lanes[#lanes + 1] = { dx, dy }
    end
    if ox == 0 and oy == 0 then
        local fx, fy = (from and from.x or cx) - cx, (from and from.y or cy) - cy
        if math.abs(fx) >= math.abs(fy) and fx ~= 0 then add(-sign(fx), 0)
        elseif fy ~= 0 then add(0, -sign(fy)) end
    elseif math.abs(ox) >= math.abs(oy) then add(sign(ox), 0)
    else add(0, sign(oy)) end
    if oy ~= 0 then add(0, sign(oy)) end
    if ox ~= 0 then add(sign(ox), 0) end
    for _, l in ipairs({ { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 } }) do add(l[1], l[2]) end
    for _, l in ipairs(lanes) do
        local dest, n = exitAlong(u, cx, cy, l[1], l[2])
        if laneClear(combat, u, l[1], l[2], n) then return dest, n end
    end
    return exitAlong(u, cx, cy, lanes[1][1], lanes[1][2])
end

-- The board helpers an eruption runs through. Live, they are the combat core's own; a cast hands in its `fx`
-- helpers instead (the Undertow), so the hover preview records rather than moves.
local function liveOps(combat, source, amount, tags, label)
    local Combat = C()
    return {
        damage = function(u)
            return Combat.dealFlatDamage(combat, u, amount, tags, label, source)
        end,
        knockback = function(u, n, opts) return Combat.knockback(combat, source, u, n, opts) end,
        placeHazard = function(x, y, id, opts)
            opts = opts or {}
            opts.side = opts.side or source.side
            return require("models.hazard").place(combat, x, y, id, opts)
        end,
    }
end

-- THE ERUPTION. Every foe of `source` in the 3x3 centred on (cx, cy) is struck once; then everyone in it, either
-- side, is shoved out; then all nine tiles become quicksand for the rest of the fight. `ops` is the helper set
-- (liveOps above, or a cast's fx). Returns the bodies it caught.
function Leviathan.erupt(combat, source, cx, cy, ops)
    local caught = Leviathan.caught(combat, cx, cy, source)
    for _, u in ipairs(caught) do
        if u.alive and u.side ~= source.side then ops.damage(u) end
    end
    for _, u in ipairs(caught) do
        if u.alive then
            local dest, n = Leviathan.exitFor(u, cx, cy, source, combat)
            ops.knockback(u, n, { dest = dest })
        end
    end
    for dy = -1, 1 do
        for dx = -1, 1 do
            ops.placeHazard(cx + dx, cy + dy, Leviathan.SAND, { duration = Leviathan.SAND_TICKS })
        end
    end
    return caught
end

local function surfaceBlow(unit)
    return math.max(1, math.floor(C().flatStat(unit, "damage") * Leviathan.SURFACE_POWER))
end

-- Lay the Ripple over the 3x3, recording the zones so the eruption can lift exactly these. Not OWNED by the body:
-- owned ground walks with its owner (Hazard.carry), and a mark that followed a shoved Leviathan would no longer
-- be where it said it would rise.
local function lay(combat, unit, cx, cy)
    local Hazard = require("models.hazard")
    local st = state(unit)
    for dy = -1, 1 do
        for dx = -1, 1 do
            local h = Hazard.place(combat, cx + dx, cy + dy, Leviathan.RIPPLE,
                { side = unit.side, duration = Leviathan.SAND_TICKS })
            if h then st.ripples[#st.ripples + 1] = h end
        end
    end
end

local function liftRipples(combat, unit)
    local Hazard = require("models.hazard")
    local st = state(unit)
    for _, h in ipairs(st.ripples) do Hazard.consume(combat, h) end
    st.ripples = {}
end

function Leviathan.dive(combat, unit)
    Status.apply(combat, unit, Leviathan.UNDER, { duration = Leviathan.UNDER_TICKS })
    state(unit).up = nil
    C().logEvent(combat, "action", string.format("%s sinks under the sand.", name(unit)), unit)
end

-- Mark the 3x3 under `target` for the head ("head") or the tail ("tail").
function Leviathan.mark(combat, unit, target, part)
    if not (target and target.alive) then return nil end
    local st = state(unit)
    local m = { x = target.x, y = target.y, on = target }
    if part == "tail" then st.tails[#st.tails + 1] = m else st.head = m end
    lay(combat, unit, m.x, m.y)
    C().logEvent(combat, "status", string.format("The sand ripples under %s.", name(target)), { unit, target })
    return m
end

-- THE RISE: the head's eruption, and the body coming up in the hole. It lands in the 3x3 wherever its footprint
-- fits (a body the shove could not move -- Rooted -- keeps its tile), or as near as the ground allows.
function Leviathan.surface(combat, unit, m)
    local Combat = C()
    Status.remove(combat, unit, Leviathan.UNDER)
    Leviathan.erupt(combat, unit, m.x, m.y, liveOps(combat, unit, surfaceBlow(unit),
        { "physical", "impact", "fire" }, "Leviathan's rising"))
    if not unit.alive then return end
    local w, h = unit.w or 1, unit.h or 1
    local ax, ay
    for _, a in ipairs({ { m.x - 1, m.y - 1 }, { m.x, m.y - 1 }, { m.x - 1, m.y }, { m.x, m.y } }) do
        if not ax and Combat.footprintFree(combat, w, h, a[1], a[2], unit) then ax, ay = a[1], a[2] end
    end
    if not ax then ax, ay = Combat.openBlockNear(combat, m.x - 1, m.y - 1, w, h, { ignore = unit }) end
    if ax then Combat.teleportUnit(combat, unit, ax, ay, { silent = true }) end
    state(unit).up = true
    Combat.logEvent(combat, "action", string.format("%s rises out of the sand!", name(unit)), unit)
end

-- The start of its own turn (trait_under_the_sand's onTurnStart): the marks laid at the end of the last one come
-- up -- the head first, then the tail's -- and a body that was already up for its round goes back under.
function Leviathan.turnStart(combat, unit)
    local st = state(unit)
    local head, tails = st.head, st.tails
    st.head, st.tails = nil, {}
    liftRipples(combat, unit)
    if head then
        Leviathan.surface(combat, unit, head)
    elseif st.up or not Leviathan.isUnder(unit) then
        -- Up for its round, or a dive the clock outran (a Stun can shove its turn past the hold): back under.
        Leviathan.dive(combat, unit)
    end
    for _, m in ipairs(tails) do
        if not unit.alive then break end
        C().logEvent(combat, "action", "Leviathan's tail breaks the sand!", unit)
        Leviathan.erupt(combat, unit, m.x, m.y, liveOps(combat, unit, surfaceBlow(unit),
            { "physical", "impact", "fire" }, "Leviathan's tail"))
    end
end

local function belowHalf(unit)
    local hp = unit.char and unit.char.stats and unit.char.stats.health
    local max = hp and C().unreservedMax(unit.char, "health")
    return hp and max and max > 0 and (hp.current or 0) < max * Leviathan.TAIL_AT
end

-- The end of its own turn (onTurnEnd): under, it marks the Fairest; below half, its tail marks the next-Fairest
-- whether the body is up or under.
function Leviathan.turnEnd(combat, unit)
    local fairest = Fairest.across(combat, unit)
    if Leviathan.isUnder(unit) then
        if fairest then Leviathan.mark(combat, unit, fairest, "head") end
        -- Refreshed, so the dive holds to the next turn however long the clock takes to come round.
        Status.apply(combat, unit, Leviathan.UNDER, { duration = Leviathan.UNDER_TICKS })
    end
    if belowHalf(unit) and fairest then
        local nextFairest = Fairest.across(combat, unit, { [fairest] = true })
        if nextFairest then Leviathan.mark(combat, unit, nextFairest, "tail") end
    end
end

-- Its death takes its marks with it.
function Leviathan.onDeath(combat, unit)
    liftRipples(combat, unit)
    local st = state(unit)
    st.head, st.tails = nil, {}
end

-- AI.preempt: under the sand it takes no action -- the turn is the dive, and the mark is laid at its end.
function Leviathan.plan(combat, unit)
    if Leviathan.isUnder(unit) and Leviathan.isLeviathan(unit) then
        return { wait = true, reason = "under the sand" }
    end
    return nil
end

-- What a cast hands Leviathan.erupt: the Undertow's own fx helpers, so a hovered aim records and a live one moves.
function Leviathan.castOps(fx)
    return {
        damage = function(u) return fx.damage(u) end,
        knockback = function(u, n, opts) return fx.knockback(u, n, opts) end,
        placeHazard = function(x, y, id, opts) return fx.placeHazard(x, y, id, opts) end,
    }
end

return Leviathan
