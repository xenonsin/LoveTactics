-- THE BUILD ENGINES (2026-11-18). The seams nine deck-builder engines hang off, in one module, so
-- combat.lua carries a call at each seam and nothing about what the engines are.
--
-- WHY THIS EXISTS. The 3x3 grid was meant to be a deck and the nine items a build, and in play it was
-- neither: a body cast its one or two highest-damage abilities and the other seven cells were stat
-- sticks. An ENGINE is the deck-builder answer -- a BUILD-UP the fight feeds, a MULTIPLIER that grows
-- it, and a PAYOFF that spends it -- and its pieces are weak alone, so collecting the set is a choice
-- rather than a pile of the best numbers. Every engine has at least one piece that reads its grid
-- neighbours, and every engine's scaling RESETS EVERY FIGHT (a unit is rebuilt per battle, and so is
-- every tally, pool and trait stack this module reads). docs/engines.md is the design.
--
--   Bloodletting (rogue)   Bleed STACKS, doubled, cashed in raw         status_bleed's `count`
--   Tempo (fighter)        quick actions since you last walked           the Duelist's `tempo` pool
--   Blood Price (barbarian) health lost on your own turn                 the `blood` pool, tally selfWound
--   Reaper (hunter)        kills pay in time: refunds, strides, haste    Engine.onFell
--   Storm Vessel (mage)    a charge a turn, spent by the spell beside it the `storm` pool
--   Overflow (priest)      healing past full, banked by the HEALER       the `radiance` pool
--   Rampart (knight)       an AMOUNT of barrier that stays and doubles   Crown's pooled barrier, made general
--   Reactions (alchemist)  Oiled + fire, Chilled + a heavy blow          Engine.afterWound
--   Grid jokers            copy, raise, relay, or reward empty cells     Trait.attach / castAmount / relay
--
-- PURE READS AND LIVE WRITES ARE KEPT APART, the same rule every ability effect lives under: the hover
-- preview and the inventory tooltip run an effect against an inert fx table, so an effect reaches a
-- mutation only through `fx.engine` (Engine.live on the real cast, Engine.inert on a dry run) and reads
-- through this module directly.
--
-- Combat, Status, Trait and the Crown are pulled LAZILY: combat.lua requires this module at load, so a
-- load-time require back would be a cycle.

local Engine = {}

local function Combat() return require("models.combat") end
local function Status() return require("models.status") end
local function Trait() return require("models.trait") end
local function Crown() return require("models.crown_demons") end
local function Character() return require("models.character") end

local function hasTag(tags, want)
    for _, t in ipairs(tags or {}) do
        if t == want then return true end
    end
    return false
end

-- Does any trait `unit` carries answer `hook`? The engines' own events (onKill, onChargeSpent) are
-- dispatched only to a body that has a listener: a dispatch opens a beat of its own (Trait's dispatch),
-- and opening one on every kill in the game would re-time answers nobody asked to move.
local function listens(unit, hook)
    for _, t in ipairs((unit and unit.traits) or {}) do
        if t.def and t.def[hook] then return true end
    end
    return false
end

local function nameOf(u)
    return (u and u.char and u.char.name) or "Unit"
end

-- ---------------------------------------------------------------------------------- the vocabulary

Engine.BLEED = "status_bleed"
Engine.OILED = "status_oiled"
Engine.CHILLED = "status_chilled"
Engine.SHATTERED = "status_shattered"
-- Next action 2 ticks sooner: Carrion Mark's kill, and a full Overflowing Cup spent.
Engine.QUICKENED = "status_quickened"
-- The Reaper's Ledger's two free steps: +2 movement until the bearer's next turn ends.
Engine.STRIDE = "status_reapers_stride"

-- The pools the engines bank into. Each is the existing charge-pool mechanism (Combat.chargeDef): an
-- item DECLARES `charge = { key, from, max }` and the pool is derived from the named tallies.
Engine.TEMPO = "tempo"         -- shared with the Duelist on purpose (the author's call, round 2)
Engine.BLOOD = "blood"
Engine.STORM = "storm"
Engine.RADIANCE = "radiance"

-- An action this quick or quicker is a QUICK action: it banks Tempo (`quickAction`), lets the
-- Afterimage Cloak lay barrier, and is what the Whetted Edge sharpens. Speed is initiative billed,
-- and an ordinary blow costs 4-6, so 2 is a jab and not a swing.
Engine.QUICK_SPEED = 2

-- Storm Vessel: every charge an adjacent spell spends multiplies it by another half.
Engine.STORM_STEP = 0.5

-- Oil going up: the blast's reach, its fire, and how long the ground burns.
Engine.OIL_RADIUS = 2
Engine.OIL_BLAST = 8
Engine.OIL_BURN = 10

-- Chilled + a hammer or axe: armour 0 for two turns.
Engine.SHATTER_TICKS = 10

-- ---------------------------------------------------------------------------------- Bloodletting

-- How many stacks of Bleed `unit` is carrying. The stack COUNT is kept apart from the status's
-- magnitude, which every weapon authors as Bleed's per-tile damage -- a stack is one more wound, not a
-- deeper one, and that is what the Bloodletting pieces multiply and cash in.
function Engine.bleedStacks(unit)
    local s = unit and unit.statuses and Status().get(unit, Engine.BLEED)
    if not s then return 0 end
    return s.count or 1
end

-- Add `n` stacks of Bleed to `unit` (opening the wound if it had none). Live only.
function Engine.addBleed(combat, unit, n, applier)
    if not (unit and unit.alive) or (n or 0) <= 0 then return nil end
    return Status().apply(combat, unit, Engine.BLEED, { stacks = n, applier = applier })
end

-- ---------------------------------------------------------------------------------- Rampart

-- What is left of `unit`'s barrier POOL: an amount of physical damage it will pay before its health
-- does. The Crown's Bulwark of the Fallen built it (models/crown_demons.lua), and the damage core, the
-- forecast and the planner already read it; the knight's engine is that pool made general.
function Engine.barrierPool(unit)
    return Crown().barrierPool(unit)
end

-- Lay `amount` more barrier on `unit`. A Bastion Plate on the bearer keeps the pool from timing out.
function Engine.grantBarrier(combat, unit, amount)
    amount = math.floor(amount or 0)
    if amount <= 0 or not (unit and unit.alive) then return 0 end
    local st = Crown().grantBarrier(combat, unit, amount)
    if st and Trait().flag(unit, "barrierHolds") then st.remaining = math.max(st.remaining or 0, 1e9) end
    if st and combat then
        Combat().logEvent(combat, "status", string.format("%s raises %d barrier (%d).",
            nameOf(unit), amount, st.pool or amount), unit)
    end
    return st and amount or 0
end

-- The Paladin's twist: a body standing next to an ally whose grid shares its barrier is covered by
-- that ally's pool too, once its own has run dry. The FIRST such sharer with anything left. Pure.
function Engine.sharedBarrierFor(unit)
    local combat = unit and unit.combat
    if not (combat and combat.units) then return nil end
    for _, u in ipairs(combat.units) do
        if u ~= unit and u.alive and u.side == unit.side and Combat().unitGap(u, unit) <= 1
            and Trait().flag(u, "sharesBarrier") and Crown().barrierPool(u) > 0 then
            return u
        end
    end
    return nil
end

-- A hit a Sentinel took FOR an ally: what it took goes onto its own pool (`guardBarrier`).
function Engine.onGuarded(combat, guardian, dealt)
    if not (guardian and guardian.alive) or (dealt or 0) <= 0 then return end
    if Trait().flag(guardian, "guardBarrier") then Engine.grantBarrier(combat, guardian, dealt) end
end

-- ---------------------------------------------------------------------------------- Blood Price

-- `unit` lost `amount` health on its OWN turn -- a self-wound, a health-paid cost, a blow answered
-- back into it mid-swing. Banks `selfWound` (the Blood pool counts these) and the running total of
-- this turn's blood, which the Scab pays back on a kill. Cleared at turn start (Engine.onTurnStart).
function Engine.noteSelfWound(combat, unit, amount)
    if not (unit and (amount or 0) > 0) then return end
    Combat().tally(unit, "selfWound", 1)
    unit.bledThisTurn = (unit.bledThisTurn or 0) + amount
end

local function isOwnTurn(combat, unit)
    local t = combat and combat.turn
    return t ~= nil and t.unit == unit
end

-- Pay `amount` of health out of `unit` as a PRICE: not a blow, so nothing softens it, and it never
-- takes the last point -- a body is never billed into the grave by its own ability. Returns what it paid.
function Engine.payHealth(combat, unit, amount)
    if not (unit and unit.char and unit.alive) then return 0 end
    local hp = unit.char.stats.health
    local spare = math.max(0, (hp.current or 0) - 1)
    local paid = math.min(spare, math.floor(amount or 0))
    if paid <= 0 then return 0 end
    hp.current = hp.current - paid
    if unit.sharedPool then Combat().syncSharedPool(combat) end
    Combat().logEvent(combat, "status", string.format("%s pays %d health.", nameOf(unit), paid), unit)
    if isOwnTurn(combat, unit) then Engine.noteSelfWound(combat, unit, paid) end
    return paid
end

-- WOUND GIFT. Does an aura beside `ab`'s item let it be paid in blood? Pure.
local function abilityItem(unit, ab)
    local inv = unit and unit.char and unit.char.inventory
    if not (inv and ab) then return nil end
    for i = 1, Character().MAX_INVENTORY do
        local it = inv[i]
        if it and it.activeAbility == ab then return it end
    end
    return nil
end

function Engine.bloodPaid(unit, ab)
    local item = abilityItem(unit, ab)
    if not item then return false end
    local char = unit.char
    local idx = Character().slotIndex(char, item)
    for _, nb in ipairs(Character().adjacentItems(char, idx)) do
        if nb.aura and nb.aura.bloodPay and Combat().auraApplies(nb.aura, item) then return true end
    end
    return false
end

-- Rewrite a cost list: a STAMINA price `unit` cannot meet is paid in health instead, when the Wound
-- Gift sits beside the ability and the body has the blood to spare (never its last point). Called from
-- Combat.abilityCosts, so the gate, the spend, the preview and the planner all read one answer.
function Engine.bloodCosts(unit, ab, costs)
    if not (unit and unit.char and ab) then return costs end
    local converted = false
    for _, c in ipairs(costs) do
        if c.stat == "stamina" and c.amount > 0 then
            local res = unit.char.stats.stamina
            local have = type(res) == "table" and (res.current or 0) or (res or 0)
            if have < c.amount and not converted then
                if not Engine.bloodPaid(unit, ab) then return costs end
                local hp = unit.char.stats.health
                if (hp.current or 0) > c.amount then
                    c.stat = "health"
                    c.bloodGift = true
                    converted = true
                end
            end
        end
    end
    return costs
end

-- ---------------------------------------------------------------------------------- Overflow

-- `healer` healed `target` past full by `overflow`. The patient side of this (the Surfeit Heart) lives
-- in Combat.bankSurfeit; this is the HEALER's: Radiance (`overheal`, a point per point, and
-- `overhealBurst`, one per overhealing heal), and the Brimming Chalice's barrier on the patient.
-- `opts.noBank` is a heal paid FOR with Radiance, which must not refill the pool it emptied.
function Engine.overheal(combat, healer, target, overflow, opts)
    overflow = math.floor(overflow or 0)
    if overflow <= 0 or not healer or (opts and opts.noBank) then return end
    Combat().tally(healer, "overheal", overflow)
    Combat().tally(healer, "overhealBurst", 1)
    if target and target.alive and Trait().flag(healer, "overhealBarrier") then
        Engine.grantBarrier(combat, target, overflow)
    end
end

-- VOTIVE FLAME (the Theurge's). A channel resolving on a bearer spends its Radiance as growth: a tick
-- of wind-up for every two points, as though the theurge had held the prayer that much longer.
function Engine.onChannelResolve(combat, unit, pending)
    if not (unit and pending) then return end
    local t = Trait().flag(unit, "votiveFlame")
    if not t then return end
    local have = Combat().chargePool(unit, Engine.RADIANCE)
    if have < 2 then return end
    local spent = Combat().spendCharge(unit, Engine.RADIANCE)
    local grow = math.floor(spent / 2)
    pending.windup = (pending.windup or 0) + grow
    pending.held = (pending.held or 0) + grow
    Combat().logEvent(combat, "action", string.format("%s feeds the votive flame: the working grows %d.",
        nameOf(unit), grow), unit)
end

-- ---------------------------------------------------------------------------------- Storm Vessel

-- The multiplier the storm pool lends a cast of `item` whose neighbouring aura spends it, or 1. Pure:
-- castAmount reads it on all three cast paths (preview, sub-strike, live), and the live cast spends
-- the pool afterwards (Engine.afterCast).
function Engine.stormFactor(unit, auraMods)
    if not (unit and auraMods and (auraMods.stormMult or 0) > 0) then return 1 end
    local n = Combat().chargePool(unit, Engine.STORM)
    if n <= 0 then return 1 end
    return 1 + auraMods.stormMult * n
end

-- ---------------------------------------------------------------------------------- Keystone

-- What one more forge level would add to `item`'s magnitude. Instantiated once per (id, level) and
-- kept: an item's numbers at a level are a pure function of its blueprint.
local stepCache = {}
function Engine.forgeStep(item)
    local ab = item and item.activeAbility
    if not (ab and item.id) then return 0 end
    local Item = require("models.item")
    if not Item.defs[item.id] then return 0 end
    local level = item.level or 0
    local key = item.id .. "@" .. level
    if stepCache[key] == nil then
        local ok, up = pcall(Item.instantiate, item.id, 1, level + 1)
        local here = Combat().abilityMagnitude(ab) or 0
        local there = ok and up and Combat().abilityMagnitude(up.activeAbility) or here
        -- A blueprint already at its ceiling still earns a step: the forge's last rung's worth.
        stepCache[key] = math.max(1, (type(there) == "number" and there or here) - (type(here) == "number" and here or 0))
        if type(here) ~= "number" then stepCache[key] = 0 end
    end
    return stepCache[key]
end

-- ---------------------------------------------------------------------------------- Relay Sigil

-- The item a RELAY fires for free when `item` is cast: the far end of `item`'s ROW, when a Relay Sigil
-- sits in the middle of it. Once per turn. nil when there is no relay, no far end, or the far end
-- cannot be aimed where this cast was.
function Engine.relayPartner(combat, unit, item, tx, ty)
    if not (unit and unit.char and item) or unit.relayedThisTurn then return nil end
    local C = Character()
    local idx = C.slotIndex(unit.char, item)
    if not idx then return nil end
    local col = (idx - 1) % C.COLS
    if col == 1 then return nil end -- a middle cell has no far end
    local row = math.floor((idx - 1) / C.COLS)
    local mid = unit.char.inventory[row * C.COLS + 2]
    if not (mid and mid.relay) then return nil end
    local far = unit.char.inventory[row * C.COLS + (col == 0 and 3 or 1)]
    local ab = far and far.activeAbility
    if not ab or far == item or not ab.effect then return nil end
    for _, t in ipairs(Combat().abilityTargets(combat, unit, far) or {}) do
        if t.x == tx and t.y == ty then return far end
    end
    return nil
end

-- ---------------------------------------------------------------------------------- the seams

-- A turn opened for `unit`: this turn's blood is fresh.
function Engine.onTurnStart(combat, unit)
    if not unit then return end
    unit.bledThisTurn = nil
    unit.relayedThisTurn = nil
end

-- `unit` WALKED `steps` tiles on its own feet. Tempo is a body planting its feet, so a walk forfeits
-- it -- unless something it carries keeps the count on the move (the Skirmisher's).
function Engine.onWalk(combat, unit, steps)
    if not unit or (steps or 0) <= 0 then return end
    if Trait().flag(unit, "tempoOnTheMove") then return end
    Combat().resetChargesOn(unit, "moved")
end

-- A deliberate action finished (resolveCast, after the effect and before the turn is billed).
-- `speed` is the initiative the action is about to cost.
function Engine.afterCast(combat, unit, item, ab, speed, auraMods)
    if not (unit and item) then return end
    -- TEMPO: a quick action banks one.
    if (speed or 99) <= Engine.QUICK_SPEED then Combat().tally(unit, "quickAction", 1) end
    -- THE STORM VESSEL: the charge a neighbouring vessel lent this cast is spent with it.
    if auraMods and (auraMods.stormMult or 0) > 0 and Combat().chargePool(unit, Engine.STORM) > 0 then
        local n = Combat().spendCharge(unit, Engine.STORM)
        if n > 0 then
            Combat().logEvent(combat, "action", string.format("%s's storm vessel empties into %s (%d).",
                nameOf(unit), item.name or "the working", n), unit)
        end
    end
    -- QUICKENED is spent by the action it quickened.
    if Status().has(unit, Engine.QUICKENED) and not (ab and ab.free) then
        Status().remove(combat, unit, Engine.QUICKENED)
    end
end

-- How much sooner `unit`'s next action comes round (Combat.actionSpeed subtracts it). Pure.
function Engine.speedRebate(unit)
    local s = unit and unit.statuses and Status().get(unit, Engine.QUICKENED)
    return s and (s.magnitude or 2) or 0
end

-- A wound landed: `dmg` off `target`, carrying `tags`, from `attacker` (nil for a tick or a trap).
-- Called from the damage core once the blow is on the body, before the death branch.
function Engine.afterWound(combat, target, dmg, tags, attacker, opts)
    if (dmg or 0) <= 0 or not target then return end
    -- BLOOD PRICE: health lost on your own turn.
    if isOwnTurn(combat, target) then Engine.noteSelfWound(combat, target, dmg) end
    -- REACTIONS. Fire finds oil.
    if hasTag(tags, "fire") and Status().has(target, Engine.OILED) and not combat._oilBlast then
        Engine.ignite(combat, target, attacker)
    end
    -- A heavy blow finds a chilled body and shatters its armour.
    local blow = opts and opts.blowItem
    if blow and Status().has(target, Engine.CHILLED)
        and (hasTag(blow.tags, "hammer") or hasTag(blow.tags, "axe")) then
        Status().remove(combat, target, Engine.CHILLED)
        Status().apply(combat, target, Engine.SHATTERED, { applier = attacker, duration = Engine.SHATTER_TICKS })
        Combat().logEvent(combat, "action", string.format("%s's chilled armour shatters.", nameOf(target)), target)
    end
end

-- OIL GOES UP: the oil is spent, everything within OIL_RADIUS takes fire, and the ground burns. A blast
-- that finds more oil sets that off too, which is the point of oiling a crowd; the latch keeps one
-- explosion from recursing into itself while it is still resolving.
function Engine.ignite(combat, body, attacker)
    Status().remove(combat, body, Engine.OILED)
    local C = Combat()
    C.logEvent(combat, "action", string.format("The oil on %s goes up.", nameOf(body)), body)
    C.spawnBurst(combat, body.x, body.y, { "fire" })
    local caught = C.unitsNear(combat, body.x, body.y, Engine.OIL_RADIUS)
    local chained = {}
    combat._oilBlast = true
    for _, u in ipairs(caught) do
        if u.alive then
            C.dealFlatDamage(combat, u, Engine.OIL_BLAST, { "fire", "magical" }, "Burning oil", attacker)
            if u.alive and Status().has(u, Engine.OILED) then chained[#chained + 1] = u end
        end
    end
    combat._oilBlast = nil
    local Hazard = require("models.hazard")
    for dy = -1, 1 do
        for dx = -1, 1 do
            pcall(Hazard.place, combat, body.x + dx, body.y + dy, "hazard_fire",
                { duration = Engine.OIL_BURN, side = attacker and attacker.side or nil })
        end
    end
    for _, u in ipairs(chained) do
        if u.alive and Status().has(u, Engine.OILED) then Engine.ignite(combat, u, attacker) end
    end
end

-- A body is going down: `target` was felled, by `attacker` (nil for a tick, a trap, the ground) with
-- `opts.blowItem`. Called at the felling blow, BEFORE the body leaves the field, so its statuses are
-- still on it to be read.
function Engine.onFell(combat, target, attacker, opts)
    if not target then return end
    local blow = opts and opts.blowItem
    -- HEMOPHAGE (the Poacher's): a bled foe's wound jumps to the nearest of its own side.
    local stacks = Engine.bleedStacks(target)
    if stacks > 0 then
        for _, u in ipairs(combat.units or {}) do
            if u.alive and u.side ~= target.side and Trait().flag(u, "hemophage") then
                local best, bestGap
                for _, o in ipairs(combat.units) do
                    if o ~= target and o.alive and o.side == target.side then
                        local gap = Combat().unitGap(o, target)
                        if not bestGap or gap < bestGap then best, bestGap = o, gap end
                    end
                end
                if best then
                    Combat().logEvent(combat, "action", string.format("%s's wound opens on %s.",
                        nameOf(target), nameOf(best)), { target, best })
                    Engine.addBleed(combat, best, stacks, u)
                end
                break
            end
        end
    end
    -- CARRION MARK: whoever marked this body is quickened by its fall, whoever felled it.
    local mark = Status().get(target, "status_carrion_mark")
    local marker = mark and mark.opener
    if marker and marker.alive and marker ~= target then
        Status().apply(combat, marker, Engine.QUICKENED, { applier = marker })
    end
    -- The killer's own pieces answer the kill (Reaper's Ledger, Scab, Butcher's Tally).
    if attacker and attacker.alive and attacker ~= target and attacker.side ~= target.side
        and listens(attacker, "onKill") then
        Trait().fire(combat, attacker, "onKill", { fallen = target, blow = blow })
    end
end

-- A pool was spent (Combat.spendCharge, live only). `full` is whether it was spent at its ceiling.
function Engine.onChargeSpent(unit, key, amount, full)
    if not unit or (amount or 0) <= 0 then return end
    Combat().tally(unit, key .. "Spent", amount)
    local combat = unit.combat
    if combat and listens(unit, "onChargeSpent") then
        Trait().fire(combat, unit, "onChargeSpent", { key = key, amount = amount, full = full })
    end
end

-- Does a status on `unit` strip its armour to nothing (Shattered)? Pure; flatStat reads it.
function Engine.zeroesDefense(unit)
    for _, s in ipairs((unit and unit.statuses) or {}) do
        if s.def and s.def.zeroesDefense then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------------- fx.engine

-- The live mutators an ability effect reaches through `fx.engine`, bound to the caster.
function Engine.live(combat, unit)
    return {
        addBleed = function(tgt, n) return Engine.addBleed(combat, tgt, n, unit) end,
        grantBarrier = function(tgt, n) return Engine.grantBarrier(combat, tgt or unit, n) end,
        setBarrier = function(tgt, n)
            tgt = tgt or unit
            local have = Engine.barrierPool(tgt)
            if n > have then return Engine.grantBarrier(combat, tgt, n - have) end
            return 0
        end,
        payHealth = function(n) return Engine.payHealth(combat, unit, n) end,
    }
end

-- The dry run's stand-in: every mutator answers what it WOULD have done and moves nothing, so an
-- effect that reads a return still branches the way the real cast will.
Engine.inert = {
    addBleed = function() return nil end,
    grantBarrier = function(_, n) return math.max(0, math.floor(n or 0)) end,
    setBarrier = function() return 0 end,
    payHealth = function(n) return math.max(0, math.floor(n or 0)) end,
}

return Engine
