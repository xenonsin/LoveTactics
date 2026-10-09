-- THE GATE AND THE PIT: the Crown's hounds, its locusts, its Reaper and its ground ("The Crown's Bestiary",
-- slice C, approved 2026-10-09). The rules the bodies and their four drops are made of, in one place:
--
--   HEARTH-BORN   a hellhound's breath leaves fire on the ground, and a hound standing in fire heals instead of
--                 burning and hits for +3 (trait_hearth_born). Wet puts the rule out. The Hellhound Collar is the
--                 same rule handed to a beastmaster's summons, without the +3 (trait_hearth_collar).
--   THREE HEADS   Cerberus bites up to three different adjacent bodies a turn, one bite per head. Each head is a
--                 HEAD (Combat.growHead) holding a third of the bar; a blow on the body lands on the fullest head,
--                 a blow aimed at a head lands on that one, and a head whose third is gone goes quiet. Honey-Cake:
--                 a Sleep on a head, or a draught thrown at it, quiets that head for 2 turns.
--   SEEK DEATH    a Pit Locust's sting cannot take a body below 1 (Trait.sparesQuarry); against a body already at
--                 1 each sting lays a stack of Torment (status_torment: -3 Damage and -1 Movement a stack, until
--                 Cured).
--   THE HARVEST   the Reaper's scythe sweeps every tile around it, and a foe in the sweep under a quarter health
--                 is downed at once. The line is drawn on every health bar while a Reaper stands (GatePit.line).
--   LETHE         grey water on the underworld's boards: a body that ends its turn in it forgets every status it
--                 carries, good and bad (hazard_lethe_shallows; Hazard.onTurnEnd).
--
-- WHY CERBERUS'S HEADS ARE UNITS, and why they take no turns. "Choose which third to break first" needs a third the
-- player can aim at, and the Chimera already built that: a head stands on no tile, is aimed at through the body's
-- head picker, and dies with the body. What a Chimera head has that these must not is a turn -- the bites are the
-- body's, all three in its one turn -- so the head blueprint is `timeless` and never enters the turn order. Its health
-- is the truth and the body's bar is their sum, kept by GatePit.sync on every wound a head takes.
--
-- Pure logic, no love.graphics. Combat, Status, Trait and Hazard are required lazily: combat.lua reaches this module
-- from its damage funnel.
local GatePit = {}

local function Combat() return require("models.combat") end
local function Status() return require("models.status") end
local function Trait() return require("models.trait") end

-- ------------------------------------------------------------------------------------------------- Hearth-Born

GatePit.HEARTH_DAMAGE = 3 -- the review's +3
GatePit.HEARTH_HEAL = 4   -- a hound heals what Burn would have taken (status_burn's magnitude)
GatePit.COLLAR_HEAL = 3   -- the Collar's own number

function GatePit.inFire(combat, u)
    if not (combat and u and u.x) then return false end
    return require("models.hazard").at(combat, u.x, u.y, "hazard_fire") ~= nil
end

-- The hound's own rule, live: carried, and not put out. Water puts it out, as it puts out a Blaze.
function GatePit.hearthBorn(u)
    if not (u and Trait().flag(u, "hearthBorn")) then return false end
    return not Status().has(u, "status_wet")
end

-- A summon of a body wearing the Hellhound Collar ("your beasts and summons").
function GatePit.collared(u)
    local s = u and u.summoner
    return s ~= nil and s.alive and Trait().flag(s, "hearthCollar") ~= nil
end

-- Fire on the ground leaves this body alone (read by hazard_fire's onEnter and `welcomes`).
function GatePit.fireproof(u)
    return GatePit.hearthBorn(u) or GatePit.collared(u)
end

-- ------------------------------------------------------------------------------------------------- Cerberus

GatePit.HEAD = "character_cerberus_head"
GatePit.QUIET_TICKS = 2 * 5 -- two turns (Status.TICKS_PER_TURN)

-- The body's living heads.
function GatePit.heads(combat, body)
    if not (combat and body) then return {} end
    return Combat().headsOf(combat, body)
end

-- A head bites while it is alive and not asleep.
function GatePit.awake(combat, body)
    local out = {}
    for _, h in ipairs(GatePit.heads(combat, body)) do
        if not Status().has(h, "status_sleep") then out[#out + 1] = h end
    end
    return out
end

-- At the bell: cut the body's bar into three equal heads, and make the bar their sum.
function GatePit.split(combat, body)
    local heads = GatePit.heads(combat, body)
    if #heads == 0 then return end
    local hp = body.char.stats.health
    local third = math.max(1, math.floor((hp.max or 0) / #heads))
    for _, h in ipairs(heads) do
        local hh = h.char.stats.health
        hh.max, hh.current = third, third
    end
    hp.max = third * #heads
    GatePit.sync(combat, body)
end

-- The body's bar is what its heads have left. A body with no head left falls.
function GatePit.sync(combat, body)
    if not (body and body.alive and body.char) then return end
    local sum = 0
    for _, h in ipairs(GatePit.heads(combat, body)) do sum = sum + math.max(0, h.char.stats.health.current or 0) end
    body.char.stats.health.current = sum
    if sum <= 0 then
        Combat().logEvent(combat, "action", string.format("The last of %s's heads goes quiet.",
            body.char.name or "the hound"), body)
        Combat().fell(combat, body)
    end
end

-- Read by Combat.dealFlatDamage before anything else touches a blow: a blow on the body lands on its fullest head.
-- A blow already aimed at a head is the head's (Combat.aimHead answers the body's cells with it), so it never
-- reaches here as a blow on the body.
function GatePit.redirect(combat, target)
    if not (target and target.alive and target.headOf == nil and Trait().flag(target, "eachHeadAThird")) then
        return nil
    end
    local best
    for _, h in ipairs(GatePit.heads(combat, target)) do
        if not best or h.char.stats.health.current > best.char.stats.health.current then best = h end
    end
    return best
end

-- HONEY-CAKE: quiet a head for two turns. A Sleep that lands on a head is cut (or stretched) to two turns, so the
-- rule reads one number whatever put it under.
function GatePit.quiet(combat, head)
    local s = Status().get(head, "status_sleep")
    if s then
        s.remaining = GatePit.QUIET_TICKS
        return true
    end
    return Status().apply(combat, head, "status_sleep", { duration = GatePit.QUIET_TICKS }) ~= nil
end

-- The foes beside `unit` other than `first`, nearest-first by board order, up to `n`.
function GatePit.othersBeside(combat, unit, first, n)
    local out = {}
    if not (combat and unit) or n <= 0 then return out end
    for _, u in ipairs(combat.units or {}) do
        if #out >= n then break end
        if u.alive and u ~= first and u ~= unit and u.side ~= unit.side and not Combat().isOffTile(u)
            and Combat().unitGap(unit, u) == 1 then
            out[#out + 1] = u
        end
    end
    return out
end

-- THREE HEADS (the Vanguard's drop): the bearer's next melee blow this turn strikes up to two more foes beside it.
-- Fired from trait_three_heads' onCast, once the swing has resolved, and spends the status whatever it found.
function GatePit.extraHeads(combat, unit, item, tx, ty)
    if not (combat and unit and unit.alive and item and item.type == "weapon") then return 0 end
    if not Status().has(unit, "status_three_heads") then return 0 end
    local melee = false
    for _, t in ipairs(item.tags or {}) do if t == "melee" then melee = true end end
    if not melee then return 0 end
    Status().remove(combat, unit, "status_three_heads")
    local first = tx and Combat().unitAt(combat, tx, ty)
    local struck = 0
    for _, foe in ipairs(GatePit.othersBeside(combat, unit, first, 2)) do
        Combat().strikeWith(combat, unit, item, foe.x, foe.y)
        struck = struck + 1
    end
    return struck
end

-- ------------------------------------------------------------------------------------------------- The Harvest

GatePit.LINE = 0.25 -- a quarter health

-- Is `u` under the line? At or under a quarter, the share Coup de Grace has always read.
function GatePit.underTheLine(u)
    local hp = u and u.char and u.char.stats.health
    if not (hp and hp.max and hp.max > 0) then return false end
    return hp.current / hp.max <= GatePit.LINE
end

-- Reap one body: under the line it is downed at once (a full-health, armour-blind blow, Coup de Grace's own), and
-- otherwise it takes the sweep. A boss is never reaped.
function GatePit.reap(fx, t)
    if not (t and t.alive) then return 0 end
    if GatePit.underTheLine(t) and not t.char.boss then
        return fx.damage(t, { amount = t.char.stats.health.max, raw = true })
    end
    return fx.damage(t)
end

-- The share the board draws a line at on every health bar, or nil when no living Reaper stands (ui/battle_map.lua).
function GatePit.line(combat)
    for _, u in ipairs((combat and combat.units) or {}) do
        if u.alive and Trait().flag(u, "harvestLine") then return GatePit.LINE end
    end
    return nil
end

-- ------------------------------------------------------------------------------------------------- Lethe

-- An injury's badge is the campaign's attrition and nothing in a fight lifts one (docs/injuries.md), so the water
-- leaves it. Read off the injury catalogue rather than listed, and only for the badge the bell stamped (its
-- lasting duration), so a Rattled from a blow is still forgotten.
local injuryIds
local function isInjuryBadge(s)
    if not injuryIds then
        injuryIds = {}
        for _, def in pairs(require("models.injury").defs) do
            for _, e in ipairs(def.effects or {}) do injuryIds[e.id] = true end
        end
    end
    return injuryIds[s.id] and (s.remaining or 0) >= require("models.injury").LASTING / 2
end

-- What the water takes: every debuff a Cure would lift and every blessing a dispel would strip. Bookkeeping
-- (a channel, the downed clock), what a body IS (`undispellable`) and an injury's badge stay.
function GatePit.forgettable(unit)
    local out = {}
    for _, s in ipairs((unit and unit.statuses) or {}) do
        local def = s.def
        if def and not def.hideLog and not def.undispellable and not isInjuryBadge(s) then out[#out + 1] = s.id end
    end
    return out
end

function GatePit.forget(combat, unit)
    if not (unit and unit.alive) then return 0 end
    local ids = GatePit.forgettable(unit)
    for _, id in ipairs(ids) do Status().remove(combat, unit, id) end
    if #ids > 0 then
        Combat().logEvent(combat, "status", string.format("%s forgets %d status%s in the grey water.",
            (unit.char and unit.char.name) or "Unit", #ids, #ids == 1 and "" or "es"), unit)
    end
    return #ids
end

return GatePit
