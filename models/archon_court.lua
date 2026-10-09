-- THE ARCHON COURT: the four bodies that wear the Archon race (data/races/archon.lua) on the Crown's floor, and the
-- rules each one adds to Spirit Body. Reviewed 2026-10-09 ("The Crown's Bestiary", slice A). One model, because
-- three of the four rules are about the COURT -- who stands near whom, and whose wisp goes where -- and they read
-- the same few facts.
--
--   MANA EDGE        the Lesser Archon's blade is cut from mana, so it lands on Magic Defense (a `magical` blade,
--                    no code here). Its drop strikes the LOWER of the two (ArchonCourt.defenseStat).
--   THE WARD         a Greater Archon throws a Magical Barrier over an Archon struck within 3 of it, once per
--                    cooldown, and opens every fight under one itself (ArchonCourt.struck).
--   HOLD THE GATE    a Warden that ended its last turn without moving holds its post: every Archon within 2 of
--                    it takes half from anything struck from farther than 2 (ArchonCourt.gateScale). A shove or
--                    a pull takes it off the post until its next still turn.
--   ASCENSION        a wisp within 3 of the Duke walks to the Duke instead of home (models/spirit.lua's
--                    `wispGoal` seam); at the third one taken (`onWispTaken`) the Duke Ascends -- a new body,
--                    healed to full, with a new spell (ArchonCourt.claimWisps / takeWisp).
--   COMMAND          at the end of each of the Duke's own turns, every Archon within 3 of it is pulled ahead of
--                    the company's soonest body on the timeline (ArchonCourt.command).
--
-- WHY THE WARDEN'S TEST IS A NAMED HELPER. The Hollow Crown's first phase takes no damage at all while a holding
-- Warden stands within 2 of its throne. That is a different consequence of the same fact, so the fact is asked one
-- way: ArchonCourt.isHolding(unit), and ArchonCourt.holdingWardenNear(combat, unit, reach) for "is one near me".
--
-- WHY THE GATE IS A LIVE READ AND NOT A STATUS. A status on each covered Archon would have to be re-laid every time
-- anybody moved -- the Warden, the Archon, or the body it is struck by. The cover is a claim about where three
-- bodies stand right now, so it is read where the damage is read (Status.damageTakenScale, through the unit's own
-- `combat` back-reference that Trait.attach lays down), and the hover forecast sees it for free.

local ArchonCourt = {}

ArchonCourt.RACE = "archon"
ArchonCourt.ASCENDED = "character_archon_duke_ascended"

local function Combat() return require("models.combat") end
local function Trait() return require("models.trait") end

local function name(u) return (u and u.char and u.char.name) or "The Archon" end

-- Is `u` one of the court? Every body that wears the race, a wisp included (a wisp IS an Archon).
function ArchonCourt.isArchon(u)
    return u ~= nil and u.char ~= nil and u.char.race == ArchonCourt.RACE
end

local function hasTag(tags, want)
    for _, t in ipairs(tags or {}) do if t == want then return true end end
    return false
end

-- ------------------------------------------------------------------------------------------------ MANA EDGE
-- The defense stat a blow lands on. `defStat` is what the blow's school already chose; a striker carrying
-- `strikesLowerDefense` (the Mana Edge drop) swaps it for whichever of the target's two defenses is lower right now.
-- A BLOW only -- a hit tagged melee or ranged, which every weapon carries and no spell does -- so a battlemage's
-- spells still land where their school says.
function ArchonCourt.defenseStat(target, defStat, tags, attacker)
    if not (attacker and target and target.char) then return defStat end
    if not (hasTag(tags, "melee") or hasTag(tags, "ranged")) then return defStat end
    if not Trait().flag(attacker, "strikesLowerDefense") then return defStat end
    local C = Combat()
    local d, m = C.flatStat(target, "defense"), C.flatStat(target, "magicDefense")
    return (m < d) and "magicDefense" or "defense"
end

-- ------------------------------------------------------------------------------------------------ THE WARD
-- `archon` was struck and stood (Spirit Body's onDamaged, which every Archon carries). The first Greater Archon of
-- its side within reach whose ward is off cooldown throws a Magical Barrier over it. A body already under one is
-- passed over, so a ward is never spent re-laying itself.
function ArchonCourt.struck(combat, archon)
    if not (combat and archon and archon.alive) or archon.wispOf then return end
    local Status = require("models.status")
    if Status.has(archon, "status_magical_barrier") then return end
    local C = Combat()
    for _, g in ipairs(combat.units or {}) do
        local t = g.alive and g.side == archon.side and Trait().flag(g, "wardsTheCourt")
        if t and C.unitGap(g, archon) <= Trait().param(t, "reach", 3) and not C.onCooldown(g, t.id) then
            Status.apply(combat, archon, "status_magical_barrier", { applier = g })
            C.setCooldown(g, t.id, Trait().param(t, "cooldown", 10))
            C.logEvent(combat, "action", string.format("%s throws a ward over %s.", name(g), name(archon)),
                { g, archon })
            return
        end
    end
end

-- ------------------------------------------------------------------------------------------------ HOLD THE GATE
-- Plant the Warden on the tile it stands on. Called at the bell and at the end of each of its own turns on which it
-- did not move. A turn it walked clears the post (it already stands somewhere else, so the read below would fail
-- anyway; clearing it keeps the field honest for anything that reads `gatePost` directly).
function ArchonCourt.post(warden, still)
    if not warden then return end
    if still then warden.gatePost = { x = warden.x, y = warden.y } else warden.gatePost = nil end
end

-- IS THIS WARDEN HOLDING RIGHT NOW? Standing, carrying the rule (and not Sundered -- Trait.flag gags it), and still
-- on the tile it planted itself on. Any move since -- its own walk, a shove, a pull, a swap -- answers no until its
-- next still turn plants it again.
function ArchonCourt.isHolding(unit)
    if not (unit and unit.alive and unit.gatePost) then return false end
    if not Trait().flag(unit, "holdsTheGate") then return false end
    return unit.x == unit.gatePost.x and unit.y == unit.gatePost.y
end

-- The first holding Warden on `unit`'s side within `reach` of it (default: the Warden's own reach), or nil. What the
-- Hollow Crown's phase 1 asks about its throne.
function ArchonCourt.holdingWardenNear(combat, unit, reach)
    if not (combat and unit) then return nil end
    local C = Combat()
    for _, w in ipairs(combat.units or {}) do
        if w.side == unit.side and ArchonCourt.isHolding(w) then
            local t = Trait().flag(w, "holdsTheGate")
            if C.unitGap(w, unit) <= (reach or Trait().param(t, "reach", 2)) then return w end
        end
    end
    return nil
end

-- The share of a blow that reaches `unit` through a holding Warden's cover: `half` when a Warden of its side holds
-- within reach of it and the striker stands farther off than that reach, 1 otherwise. The Warden's own organ covers
-- Archons only (`court`); the drop covers every ally. Asked by Status.damageTakenScale; a blow with no striker in
-- hand (a trap, a burn, a hover with no attacker) is not "struck from" anywhere and reads full.
function ArchonCourt.gateScale(unit, attacker)
    if not (unit and attacker and attacker ~= unit and attacker.side ~= unit.side) then return 1 end
    local combat = unit.combat
    if not (combat and combat.units) then return 1 end
    local C = Combat()
    for _, w in ipairs(combat.units) do
        if w.side == unit.side and ArchonCourt.isHolding(w) then
            local t = Trait().flag(w, "holdsTheGate")
            local reach = Trait().param(t, "reach", 2)
            if (not Trait().param(t, "court", false) or ArchonCourt.isArchon(unit))
                and C.unitGap(w, unit) <= reach and C.unitGap(attacker, unit) > reach then
                return Trait().param(t, "share", 0.5)
            end
        end
    end
    return 1
end

-- ------------------------------------------------------------------------------------------------ ASCENSION
-- Turn every walking wisp of the Duke's side within its reach toward the Duke (models/spirit.lua's `wispGoal`). Asked
-- whenever anything changes where a wisp is -- a death throws one, and every turn start and end may have moved one --
-- so a wisp that WANDERS into reach is claimed as surely as one thrown there. A Duke that has already Ascended takes
-- no more.
function ArchonCourt.claimWisps(combat, duke)
    if not (combat and duke and duke.alive) or duke.ascended then return end
    local t = Trait().flag(duke, "takesWisps")
    if not t then return end
    local C = Combat()
    local reach = Trait().param(t, "reach", 3)
    for _, w in ipairs(combat.units or {}) do
        if w.alive and w.wispOf and w.side == duke.side and w.wispGoal ~= duke
            and not (w.wispGoal and w.wispGoal.alive) and C.unitGap(w, duke) <= reach then
            w.wispGoal = duke
            C.logEvent(combat, "status", string.format("The wisp turns toward %s.", name(duke)), { w, duke })
        end
    end
end

-- The Duke took a wisp (`onWispTaken`, fired by Spirit.tryArrive). Counted on the UNIT, because Ascending re-attaches
-- the body's traits and a count kept on the trait would be thrown away with it. At the third, it Ascends: the shape
-- in ArchonCourt.ASCENDED, minted at its own level, healed to full -- a boss stays a boss in its new body.
function ArchonCourt.takeWisp(combat, duke, trait)
    if not (combat and duke and duke.alive) or duke.ascended then return end
    local C = Combat()
    local need = trait and Trait().param(trait, "need", 3) or 3
    duke.wispsTaken = (duke.wispsTaken or 0) + 1
    if trait then trait.stacks = math.min(duke.wispsTaken, need) end
    C.logEvent(combat, "action", string.format("%s takes the wisp in (%d of %d).", name(duke), duke.wispsTaken, need),
        duke)
    if duke.wispsTaken < need then return end
    local boss = duke.char and duke.char.boss
    local shape = require("models.transform").apply(combat, duke, ArchonCourt.ASCENDED,
        { level = duke.char and duke.char.level })
    if not shape then return end
    if boss then shape.boss = true end
    duke.ascended = true
    shape.stats.health.current = C.unreservedMax(shape, "health")
    C.logEvent(combat, "action", string.format("%s Ascends.", (require("models.transform").originalChar(duke) or {}).name
        or "The Duke"), duke)
end

-- ------------------------------------------------------------------------------------------------ COMMAND
-- The smallest coherent Command: at the end of each of the Duke's own turns (and at the bell), every OTHER Archon of
-- its side within reach is pulled ahead of the company's soonest body on the timeline -- one tick before it, never
-- below 0, and never pushed back. A body already due sooner is left where it is. At 0 a tie goes to the company
-- (Combat.turnOrder's side rank), which is the one case it cannot win and is left alone rather than reaching below 0,
-- where Combat.rebase would count a negative tick as time passing.
function ArchonCourt.command(combat, duke)
    if not (combat and duke and duke.alive) then return end
    local t = Trait().flag(duke, "commandsTheCourt")
    if not t then return end
    local C = Combat()
    local soonest
    for _, u in ipairs(combat.units or {}) do
        if u.side ~= duke.side and C.inTimeline(u) and (not soonest or u.initiative < soonest) then
            soonest = u.initiative
        end
    end
    if not soonest or soonest <= 0 then return end
    local reach = Trait().param(t, "reach", 3)
    local to = math.max(0, soonest - 1)
    local pulled = 0
    for _, u in ipairs(combat.units) do
        if u ~= duke and u.side == duke.side and C.inTimeline(u) and ArchonCourt.isArchon(u)
            and C.unitGap(duke, u) <= reach and u.initiative > to then
            u.initiative = to
            pulled = pulled + 1
        end
    end
    if pulled > 0 then
        C.logEvent(combat, "action", string.format("%s commands, and its court moves first.", name(duke)), duke)
    end
end

return ArchonCourt
