-- SLOTH'S BESTIARY, SLICE C (2026-10-04, "Sloth's Bestiary"): the Bog-Bound, the Frost Worm and the Noonday
-- Demon. The rules their organs carry, in one place so the trait files stay short and the spec has one module
-- to pin.
--
--   PAST FEELING     a blow of 8 damage or less does nothing to one of the Bog-Bound; anything heavier lands in
--                    full. Asked from Combat.dealFlatDamage past the crit, and from Combat.computeDamage, so the
--                    hover quotes the 0. The threshold is printed on the body's badge (status_past_feeling).
--   THE MIRE HOLDS   a body that starts its turn beside one of the Bog-Bound pays 2 movement on the step that
--                    takes it away from that one. Priced in Combat's stepTerrainCost, the one place a tile is
--                    priced, so the move overlay, a steered route and the walk itself agree. A shove or a pull
--                    is not a step, so it never pays.
--   DEEPER PEAT      within 3 of a Cairn-Keeper of its side, both of the above are doubled: a threshold of 16,
--                    a toll of 4. The Keeper stands inside its own reach.
--   LISTLESS         a foe of the Noonday Demon within 4 that ends its turn having dealt no damage gains a stack
--                    (-3 Damage each). Three, and its next turn is Shamed. Any damage it deals clears them all.
--                    The Meridian Charm lays the same stacks at 3 and never shames.
--
-- WHAT "DEALT DAMAGE" MEANS is a wound that reached the flesh (SlothBog.struck, from dealFlatDamage's landed
-- path) on the body's own turn. A blow Past Feeling swallowed reached nothing, so a company chipping at the
-- Bog-Bound beside the Demon is a company doing nothing in its eyes -- the two lines are fielded together on
-- purpose.
--
-- Pure logic, no love.graphics. Combat, Status and Trait are required lazily: combat.lua and status.lua both
-- reach this module.
local SlothBog = {}

SlothBog.FEELING = 8               -- Past Feeling: a blow this size or smaller does nothing
SlothBog.TOLL = 2                  -- The Mire Holds: movement paid to step away
SlothBog.DEEPER_REACH = 3          -- Deeper Peat: the Cairn-Keeper's reach
SlothBog.DEEPER_FACTOR = 2         -- ...and what it does to both numbers
SlothBog.BADGE = "status_past_feeling"
SlothBog.LISTLESS = "status_listless"
SlothBog.LISTLESS_REACH = 4        -- the Demon's
SlothBog.SHAME_AT = 3              -- Listless stacks that cost the next turn
SlothBog.SHAMED = "status_shamed"

-- A body that ever carried the Mire has been seen this session, so the step pricing below is worth asking.
-- Every other board pays one boolean per step (the pattern Trait.presenceLive keeps).
SlothBog.live = false

local function Trait() return require("models.trait") end
local function Combat() return require("models.combat") end
local function Status() return require("models.status") end

local function name(u) return (u and u.char and u.char.name) or "Unit" end

-- ------------------------------------------------------------------------------------------ deeper peat

-- Does a Cairn-Keeper of `u`'s side (u itself included) stand within its reach of `u`? Through Trait.flag, so a
-- Sundered Keeper's peat goes shallow again -- "kill or break the Cairn-Keeper first".
function SlothBog.deeper(u)
    local combat = u and u.combat
    if not (combat and combat.units) then return false end
    local C = Combat()
    for _, k in ipairs(combat.units) do
        if k.alive and k.side == u.side then
            local t = Trait().flag(k, "deeperPeat")
            if t and C.unitGap(k, u) <= Trait().param(t, "deeperPeat", SlothBog.DEEPER_REACH) then return true end
        end
    end
    return false
end

local function factor(u) return SlothBog.deeper(u) and SlothBog.DEEPER_FACTOR or 1 end

-- ----------------------------------------------------------------------------------------- past feeling

-- `u`'s threshold right now: 8, 16 inside Deeper Peat, 0 for anybody who is not Bog-Bound. Keeps the badge's
-- printed number in step as a side effect, so the number on the body is the number the next blow meets.
function SlothBog.threshold(u)
    if not (u and u.alive ~= false and Trait().flag(u, "pastFeeling")) then return 0 end
    local t = SlothBog.FEELING * factor(u)
    local badge = Status().get(u, SlothBog.BADGE)
    if badge then badge.magnitude = t end
    return t
end

-- What of a wound of `dmg` reaches `target`. 0 when Past Feeling swallows it; the wound itself otherwise.
-- Pure but for the badge sync above, so the forecast can ask it.
function SlothBog.pastFeeling(target, dmg)
    if not (dmg and dmg > 0) then return dmg end
    local t = SlothBog.threshold(target)
    if t > 0 and dmg <= t then return 0 end
    return dmg
end

-- Re-read every Bog-Bound body's badge (a Keeper walked, or fell). Called off the organ's turn hooks.
function SlothBog.sync(combat)
    for _, u in ipairs((combat and combat.units) or {}) do
        if u.alive then SlothBog.threshold(u) end
    end
end

-- ---------------------------------------------------------------------------------------- the mire holds

-- Who holds `unit` this turn, and at what toll: every living foe carrying the Mire that stood beside the tile
-- this turn opened on. Measured once per turn and kept on the turn record, so the Dijkstra pays one lookup per
-- step rather than a roster walk. Deeper Peat is read at that moment too.
local function holders(combat, unit)
    local turn = combat.turn
    if turn.mireHolders then return turn.mireHolders end
    local out = {}
    local C = Combat()
    local start = { x = turn.startX or unit.x, y = turn.startY or unit.y, w = unit.w, h = unit.h }
    for _, h in ipairs(combat.units or {}) do
        if h.alive and h ~= unit and h.side ~= unit.side and not C.isOffTile(h)
            and Trait().flag(h, "mireHolds") and C.unitGap(h, start) == 1 then
            out[#out + 1] = { unit = h, toll = SlothBog.TOLL * factor(h) }
        end
    end
    turn.mireHolders = out
    return out
end

-- The movement a step from (fx, fy) to (x, y) owes the Mire: the toll of every holder the step leaves the side of.
-- Only on the mover's own turn and only for a step it walks (a shove never asks here). 0 for everyone else.
function SlothBog.mireToll(combat, unit, fx, fy, x, y)
    if not (SlothBog.live and fx and combat and combat.turn and combat.turn.unit == unit) then return 0 end
    local list = holders(combat, unit)
    if #list == 0 then return 0 end
    local C = Combat()
    local from = { x = fx, y = fy, w = unit.w, h = unit.h }
    local to = { x = x, y = y, w = unit.w, h = unit.h }
    local toll = 0
    for _, e in ipairs(list) do
        if e.unit.alive and C.unitGap(e.unit, from) == 1 and C.unitGap(e.unit, to) > 1 then toll = toll + e.toll end
    end
    return toll
end

-- ----------------------------------------------------------------------------------------- the cairn stone

-- Is `unit` held in place by a Cairn Stone of its side (`anchorsAllies`, the reach as the value)? The bearer
-- counts. Read by Status.blocksForcedMove; through Trait.flag, so a Sundered bearer anchors nobody.
function SlothBog.anchored(unit)
    local combat = unit and unit.combat
    if not (combat and combat.units) or unit.alive == false then return false end
    local C = Combat()
    for _, b in ipairs(combat.units) do
        if b.alive and b.side == unit.side then
            local t = Trait().flag(b, "anchorsAllies")
            if t and C.unitGap(b, unit) <= Trait().param(t, "anchorsAllies", 3) then return true end
        end
    end
    return false
end

-- -------------------------------------------------------------------------------------------- listless

-- `attacker` landed a wound. Stamp the turn it was dealt on, and lift every Listless stack: dealing damage is
-- the whole cure. Called from Combat.dealFlatDamage's landed path, for a known attacker only.
function SlothBog.struck(combat, attacker, target)
    if not (combat and attacker and attacker ~= target) then return end
    attacker.woundTurn = combat.turnCount
    if Status().has(attacker, SlothBog.LISTLESS) then
        Status().remove(combat, attacker, SlothBog.LISTLESS)
        Combat().logEvent(combat, "status", string.format("%s shakes off the afternoon.", name(attacker)), attacker)
    end
end

-- Did `u` deal damage on the turn now ending?
function SlothBog.dealtThisTurn(combat, u)
    return u.woundTurn ~= nil and u.woundTurn == combat.turnCount
end

-- `actor`'s turn just ended within `reach` of `bearer`: if it was a foe that dealt nothing, it grows Listless.
-- `shames` marks the stacks the Demon laid, which cost the turn at three (the charm's never do).
function SlothBog.idleTurn(combat, bearer, actor, reach, shames)
    if not (combat and bearer and bearer.alive and actor and actor.alive and actor.side ~= bearer.side) then return end
    if actor.summoned or actor.decoyOf or Combat().isOffTile(actor) then return end
    if Combat().unitGap(bearer, actor) > reach then return end
    if SlothBog.dealtThisTurn(combat, actor) then return end
    local st = Status().apply(combat, actor, SlothBog.LISTLESS, { applier = bearer })
    if st and shames then st.shames = true end
end

return SlothBog
