-- SLOTH'S APPROACH BEASTS (2026-10-04, "Sloth's Bestiary", slice A): the ground sloths and the yeti of the
-- tundra's approach. One module for the four bodies' machinery and the three trophies that wear it, so every rule
-- that has two holders (a body's and a drop's) is written once.
--
--   THE BANK        a ground sloth does nothing on a turn no foe is in its reach, and the turn is banked
--                   (status_banked, through models/bank.lua, each keeper at its own cap); its next swing lands
--                   once per banked turn and once more for the turn itself; a blow that lands on it knocks one
--                   turn out. The Old Sloth spends the same bank as ring sweeps. Sleeper's Claws is the bank on a
--                   monk's fist.
--   WHITEOUT ROAR   at the top of a yeti's turn, every foe within 4 with no ally beside it is Rooted. The
--                   Yeti-Hide Mantle roots the nearest such foe within 3.
--   DRAG INTO THE WHITE   the Dread hauls a Rooted body 3 tiles toward her -- through the Root, which is the whole
--                   point of the pairing: the yeti's fear pins a body, and she is the one thing that can move it.
--   HIBERNAL HIDE   the blow that wakes the wearer from Sleep deals half, and the first blow it throws after waking
--                   deals 50% more.
--
-- Pure logic over Combat/Status/Trait/Bank, every one lazily required: trait blueprints require this module at
-- load, inside the trait registry's own load, so it must pull nothing in at the top.
local SlothBeasts = {}

local Bank = setmetatable({}, { __index = function(_, k) return require("models.bank")[k] end })
local function Combat() return require("models.combat") end
local function Status() return require("models.status") end
local function Trait() return require("models.trait") end

local function nameOf(u) return (u and u.char and u.char.name) or "It" end

-- ---------------------------------------------------------------------------
-- The bank
-- ---------------------------------------------------------------------------

-- Is any foe of `unit` within its reach THIS turn: a body its default weapon can strike from where it stands or
-- from any tile it could walk to. The question a ground sloth asks before it bothers to move at all. A pure read,
-- because the planner (and its every-hover intent preview) is the one that asks it.
function SlothBeasts.foeInReach(combat, unit)
    local C = Combat()
    local weapon = C.defaultWeapon(unit.char)
    local ab = weapon and weapon.activeAbility
    if not ab then return false end
    local nodes = C.reachableList(combat, unit)
    nodes[#nodes + 1] = { x = unit.x, y = unit.y, steps = 0 }
    for _, foe in ipairs(combat.units or {}) do
        if foe.alive and foe.side ~= unit.side and not C.isOffTile(foe) then
            for _, node in ipairs(nodes) do
                local range = C.abilityRange(combat, unit, ab, node.x, node.y)
                if C.reachFrom(unit, node.x, node.y, foe) <= math.max(1, range) then return true end
            end
        end
    end
    return false
end

-- THE PLANNER'S HALF (AI.preempt): a sloth with no foe in reach does nothing at all. The bank is earned at the
-- turn's end by its organ (SlothBeasts.bankTurnEnd), never here -- a plan is dry-run on every hover. Never a body
-- the player drives.
function SlothBeasts.plan(combat, unit)
    if unit.side == "party" or not Trait().flag(unit, "idlesUntilReach") then return nil end
    if SlothBeasts.foeInReach(combat, unit) then return nil end
    return { wait = true, reason = "banking the turn" }
end

-- Was this cast an attack: a weapon swung, or an ability aimed at a foe. What "a turn ended without attacking"
-- reads, for both the sloth's organ and the monk's claws.
local function attacking(ctx)
    local item, ab = ctx.item, ctx.ability or (ctx.item and ctx.item.activeAbility)
    if item and item.type == "weapon" then return true end
    return ab ~= nil and ab.target == "enemy"
end

-- onCast: mark the turn as one the bearer attacked in.
function SlothBeasts.markSwing(ctx)
    if ctx.unit and attacking(ctx) then ctx.unit._slothSwung = true end
end

-- onTurnEnd: a turn ended without an attack is banked, up to the keeper's own cap (`cap` on the trait or its
-- item's traitParams). The mark is cleared either way, for the next turn.
function SlothBeasts.bankTurnEnd(ctx)
    local u = ctx.unit
    if not (u and u.alive) then return end
    if u._slothSwung then u._slothSwung = nil return end
    local before = Bank.count(u)
    local now = Bank.add(ctx.combat, u, 1, ctx.param("cap", 3))
    if now > before then
        Combat().logEvent(ctx.combat, "status", string.format("%s banks the turn (%d).", nameOf(u), now), u)
    end
end

-- onDamaged: a blow that lands on a keeper knocks one turn out of its bank. Only a BLOW -- a wound with a striker
-- behind it -- so a Burn ticking or a trap springing knocks nothing.
function SlothBeasts.knock(ctx)
    local u = ctx.unit
    if not (u and u.alive and ctx.attacker and (ctx.amount or 0) > 0) then return end
    if Bank.count(u) > 0 then Bank.knock(ctx.combat, u) end
end

-- How many times a keeper's swing lands this cast: once for the turn itself, and once per banked turn. Read off
-- the badge, so the number the player saw is the number that lands. The caller spends the bank through
-- fx.clearStatus, which the damage previews hold inert.
function SlothBeasts.swings(unit)
    return 1 + Bank.count(unit)
end

-- ---------------------------------------------------------------------------
-- The Old Sloth's ring
-- ---------------------------------------------------------------------------

-- Every cell BESIDE `unit`'s footprint (orthogonally adjacent to some cell of it, and not under it). The Old
-- Sloth's sweep, aimed wherever: its ring is the same four sides of a 2x2 body whatever tile it picked.
function SlothBeasts.ringCells(unit)
    local x, y, w, h = unit.x, unit.y, unit.w or 1, unit.h or 1
    local cells = {}
    for i = 0, w - 1 do
        cells[#cells + 1] = { x = x + i, y = y - 1 }
        cells[#cells + 1] = { x = x + i, y = y + h }
    end
    for j = 0, h - 1 do
        cells[#cells + 1] = { x = x - 1, y = y + j }
        cells[#cells + 1] = { x = x + w, y = y + j }
    end
    return cells
end

-- ---------------------------------------------------------------------------
-- The whiteout
-- ---------------------------------------------------------------------------

-- Has `body` no ally beside it: no living, standing body of its own side at a gap of 1.
function SlothBeasts.alone(combat, body)
    local C = Combat()
    for _, u in ipairs(combat.units or {}) do
        if u ~= body and u.alive and not u.incapacitated and u.side == body.side and not C.isOffTile(u)
            and C.unitGap(u, body) == 1 then
            return false
        end
    end
    return true
end

-- Every foe of `roarer` within `radius` that stands alone, nearest first (ties in board order, so two machines
-- root the same body).
function SlothBeasts.lonely(combat, roarer, radius)
    local C = Combat()
    local out = {}
    for _, f in ipairs(combat.units or {}) do
        if f.alive and f.side ~= roarer.side and not C.isOffTile(f) and C.unitGap(roarer, f) <= radius
            and SlothBeasts.alone(combat, f) then
            out[#out + 1] = f
        end
    end
    table.sort(out, function(a, b)
        local da, db = C.unitGap(roarer, a), C.unitGap(roarer, b)
        if da ~= db then return da < db end
        if a.y ~= b.y then return a.y < b.y end
        return a.x < b.x
    end)
    return out
end

-- WHITEOUT ROAR (onTurnStart): Root every lonely foe within `radius` (or only the nearest, for the mantle).
function SlothBeasts.roar(ctx)
    local u = ctx.unit
    if not (u and u.alive) then return end
    local caught = SlothBeasts.lonely(ctx.combat, u, ctx.param("radius", 4))
    if #caught == 0 then return end
    if ctx.param("nearest", false) then caught = { caught[1] } end
    for _, f in ipairs(caught) do
        ctx.applyStatus(f, "status_root", { applier = u })
        Combat().logEvent(ctx.combat, "status",
            string.format("%s is caught alone in the white and freezes with fear.", nameOf(f)), { f, u })
    end
end

-- DRAG INTO THE WHITE (onTurnStart): the Dread hauls the nearest Rooted foe within `reach` up to `steps` tiles
-- toward her. THROUGH THE ROOT: Root refuses every forced move (Status.blocksForcedMove), so the instance is lifted
-- off for the haul and put back after it, and the body arrives still Rooted -- held where she wanted it. Anything
-- else that plants a body (Unmoved, a Mast-Rope) still holds. Returns the tiles moved.
function SlothBeasts.drag(combat, dread, reach, steps)
    local C, S = Combat(), Status()
    local best
    for _, f in ipairs(combat.units or {}) do
        if f.alive and f.side ~= dread.side and not C.isOffTile(f) and S.has(f, "status_root") then
            local d = C.unitGap(dread, f)
            if d > 1 and d <= reach and (not best or d < C.unitGap(dread, best)) then best = f end
        end
    end
    if not best then return 0 end
    local root = S.get(best, "status_root")
    for i, s in ipairs(best.statuses) do
        if s == root then table.remove(best.statuses, i) break end
    end
    local moved = C.pullBy(combat, dread, best, steps)
    if best.alive then table.insert(best.statuses, root) end
    if moved > 0 then
        C.logEvent(combat, "move", string.format("%s drags %s into the white.", nameOf(dread), nameOf(best)),
            { best, dread })
    end
    return moved
end

-- ---------------------------------------------------------------------------
-- Hibernal Hide
-- ---------------------------------------------------------------------------

SlothBeasts.SLEEPS = { status_sleep = true, status_dormant = true }

local function asleep(u)
    local S = Status()
    for id in pairs(SlothBeasts.SLEEPS) do
        if S.has(u, id) then return true end
    end
    return false
end

-- onStatusApplied: a Sleep landing on the wearer is padded -- the instance carries damageTakenScale 0.5 (read by
-- Status.damageTakenScale), so the blow that ends it lands at half, and the wearer is marked as sleeping.
function SlothBeasts.hibernate(ctx)
    local s = ctx.status
    if ctx.role ~= "recipient" or not (s and SlothBeasts.SLEEPS[s.id]) then return end
    s.damageTakenScale = ctx.param("woken", 0.5)
    ctx.unit._hibernating = true
end

-- onDamaged / onTurnStart: a wearer that was sleeping and is not any more has woken, and its next blow is primed.
-- A wound counts as the waking on its own: the traits hear a blow BEFORE the statuses riding the body do
-- (Combat's held answers), so the Sleep is still on the badge when this runs and is about to break.
function SlothBeasts.checkWake(ctx)
    local u = ctx.unit
    if u and u._hibernating and ((ctx.amount or 0) > 0 or not asleep(u)) then
        u._hibernating = nil
        u._hibernalWoke = true
    end
end

-- damageBonusVs: the primed blow deals 50% more -- half of the weapon and the attack stat behind it, added
-- before armour. A pure read; the prime is spent by SlothBeasts.spendWake once the cast resolves.
function SlothBeasts.wakeBonus(ctx)
    local u = ctx.unit
    if not (u and u._hibernalWoke) then return 0 end
    local C = Combat()
    local ab = ctx.blow and ctx.blow.activeAbility
    local magical = ctx.hasTag("magical")
    local base = ((ab and C.abilityMagnitude(ab)) or 0) + C.flatStat(u, magical and "magicDamage" or "damage")
    return math.floor(base * ctx.param("bonus", 0.5))
end

-- onCast: an attack spends the prime.
function SlothBeasts.spendWake(ctx)
    if ctx.unit and ctx.unit._hibernalWoke and attacking(ctx) then ctx.unit._hibernalWoke = nil end
end

return SlothBeasts
