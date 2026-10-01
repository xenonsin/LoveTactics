-- PRIDE'S ONE-OFF ELITES (reviewed 2026-09-30, "Pride's Bestiary"): the Unicorn and the Sphinx on the spire's
-- approach, the Phoenix and the Tower-Giant on its seat. Four creatures from four myths about pride, each its
-- own encounter, met again on the next trip like every elite -- so nothing here is a one-time story beat, and
-- every rule reads the board it is standing on.
--
--   THE UNICORN      rejects the unworthy: it cannot be hurt by a body carrying a debuff, a curse or an
--                    injury, and its horn decides who that is (a body it strikes is Blighted, a debuff).
--   THE SPHINX       is never wrong: each of its turns it asks a riddle of the company, dealt off the fight's
--                    own seed. Meet it before its next turn and it can be hurt until then; fail it and it
--                    heals a tenth. Unanswered, it takes nothing at all.
--   THE PHOENIX      never repents, only returns: felled, it burns down to an Ember that rises again as the
--                    Phoenix in three turns, at full health and 3 Damage the stronger for every death.
--   THE TOWER-GIANT  is ambition: a stack of Ambition every turn, and when it falls it crashes on everything
--                    within 1 + a third of them, for 6 damage a stack.
--
-- The wards are ANSWERED IN Status.immuneToDamage, beside Pride's slime rank, so the hover preview, the log
-- and the live blow see one answer. Everything else rides the bodies' own organs (data/traits/). Pure logic,
-- headless-safe; Combat and Status are reached lazily, since models/status.lua requires this file at blow
-- time and this file needs them back.

local PrideElites = {}

-- ------------------------------------------------------------------------------------------- the Unicorn

-- WHAT MAKES A BODY UNWORTHY, and only these three. Asked of the ATTACKER, on every blow at the Unicorn.
--   a debuff   any status declaring `debuff = true` -- which is what Blighted is, so the horn's own blow
--              is what turns a body away. A Cure makes it worthy again, which is the answer.
--   a curse    a hexed piece in its grid (Curse.countOn), or the Cursed status on its body.
--   an injury  a share of a pool set aside by one (char.injuryShare, every kind carries one), or any of
--              the injury badges stamped at the bell. Neither is a debuff -- the Ward is the only room that
--              ends one -- so a veteran carried out of a bad floor cannot touch this body until it rests.
-- Returns the reason as a word ("a debuff", "a curse", "an injury"), or nil for a worthy body.
local injuryStatuses -- built once: every status an injury stamps
local function injuryBadge(unit)
    if not injuryStatuses then
        injuryStatuses = {}
        for _, def in pairs(require("models.injury").defs) do
            for _, effect in ipairs(def.effects or {}) do injuryStatuses[effect.id] = true end
        end
    end
    for _, s in ipairs(unit.statuses or {}) do
        if injuryStatuses[s.id] then return true end
    end
    return false
end

function PrideElites.unworthy(unit)
    if not unit then return nil end
    for _, s in ipairs(unit.statuses or {}) do
        if s.def and s.def.debuff then return "a debuff" end
    end
    local char = unit.char
    if require("models.status").has(unit, "status_cursed") then return "a curse" end
    if char and require("models.curse").countOn(char) > 0 then return "a curse" end
    for _, share in pairs((char and char.injuryShare) or {}) do
        if (share or 0) > 0 then return "an injury" end
    end
    if injuryBadge(unit) then return "an injury" end
    return nil
end

-- ------------------------------------------------------------------------------------------- the wards

local UNWORTHY = { id = "unworthy", name = "Unworthy" }
local UNANSWERED = { id = "unanswered", name = "Unanswered" }

-- The riddle trait on `unit` that WARDS it (the Sphinx's own; the Sphinx's Riddle a company carries asks
-- without warding, `traitParams.wards = false`), or nil.
local function riddleWard(unit)
    local t = require("models.trait").flag(unit, "riddler")
    if t and require("models.trait").param(t, "wards", true) then return t end
    return nil
end

-- The ward that voids a blow on `unit`, struck by `attacker` (nil for a trap, a burn or a probe), or nil.
-- Read by Status.immuneToDamage. A live board only (`unit.combat`): a stat-line probe in the balance
-- tools has no riddle to answer and no attacker to judge, and must measure the body as a body.
function PrideElites.ward(unit, attacker)
    if not (unit and unit.traits and unit.combat) then return nil end
    local Trait = require("models.trait")
    if attacker and attacker ~= unit and attacker.side ~= unit.side and Trait.flag(unit, "rejectsUnworthy")
        and PrideElites.unworthy(attacker) then
        return UNWORTHY
    end
    if riddleWard(unit) and not require("models.status").has(unit, PrideElites.ANSWERED) then
        return UNANSWERED
    end
    return nil
end

-- The Unicorn's horn washes its own side at the end of each of its turns: every debuff on every body of
-- its side, itself included. Returns how many were lifted.
function PrideElites.purify(combat, unicorn)
    local Status = require("models.status")
    local lifted = 0
    for _, u in ipairs(combat.units or {}) do
        if u.alive and u.side == unicorn.side then lifted = lifted + Status.cleanse(combat, u) end
    end
    if lifted > 0 then
        require("models.combat").logEvent(combat, "status", string.format("%s's horn cleanses its side.",
            (unicorn.char and unicorn.char.name) or "The Unicorn"), unicorn)
    end
    return lifted
end

-- ------------------------------------------------------------------------------------------- the Sphinx

PrideElites.ANSWERED = "status_riddle_answered"

-- THE RIDDLES. Each is a question about what the side being asked did between one of the asker's turns and
-- the next, and each is answerable by an ordinary company: a torch or a fire spell, standing still, one
-- blade, a bow or a wand, two blades. A STRIKE is any cast whose ability deals damage; who it caught is read
-- off its footprint, and a strike counts whether the ward voided it or not -- the swing is the answer.
--
-- `text` completes "<Asker> asks: ..." and is the badge's own line too (data/status/status_riddle_*.lua).
PrideElites.RIDDLES = {
    { id = "fire", status = "status_riddle_fire",
      text = "one of you strikes with fire",
      met = function(r) return r.fire end },
    { id = "stillness", status = "status_riddle_stillness",
      text = "none of you moves",
      met = function(r) return not r.moved end },
    { id = "alone", status = "status_riddle_alone",
      text = "exactly one of you attacks",
      met = function(r) return r.strikers == 1 end },
    { id = "distance", status = "status_riddle_distance",
      text = "one of you strikes from 3 or more tiles away",
      met = function(r) return r.far end },
    { id = "together", status = "status_riddle_together",
      text = "two of you strike the same foe",
      met = function(r) return r.together end },
}
PrideElites.FAR = 3          -- a strike from this many tiles off answers Distance
PrideElites.FAIL_HEAL = 0.10 -- what a failed round heals the Sphinx, as a share of its health

local function newRecord()
    return { moved = false, strikers = 0, strikerSet = {}, struck = {}, fire = false, far = false,
             together = false }
end

-- Is `u` one of the bodies `t` (a riddle trait on `bearer`) is asking? The Sphinx asks its foes; the
-- Sphinx's Riddle asks its bearer's own side (`traitParams.asks = "own"`).
local function asked(t, bearer, u)
    if not (u and u.side) then return false end
    if require("models.trait").param(t, "asks", "foes") == "own" then return u.side == bearer.side end
    return u.side ~= bearer.side
end

local function hasTag(list, want)
    for _, x in ipairs(list or {}) do if x == want then return true end end
    return false
end

-- Record a cast by `caster` into the round the trait `t` (on `bearer`) is judging.
function PrideElites.noteCast(combat, t, bearer, caster, item, ab, tx, ty)
    local r = t.record
    if not (r and ab and ab.damage and caster and asked(t, bearer, caster)) then return end
    if not r.strikerSet[caster] then
        r.strikerSet[caster] = true
        r.strikers = r.strikers + 1
    end
    local Combat = require("models.combat")
    local fire = hasTag(item and item.tags, "fire") or hasTag(ab.tags, "fire")
    local cells = (ab.aoe and tx) and Combat.aoeCells(combat, ab, tx, ty, caster) or { { x = tx, y = ty } }
    local seen = {}
    for _, c in ipairs(cells) do
        -- The body on the cell -- or one that fell to this very cast, which unitAt no longer answers with:
        -- a blow that kills is still a blow that landed.
        for _, v in ipairs(combat.units or {}) do
            local covers = c.x and v.x and c.x >= v.x and c.x <= v.x + (v.w or 1) - 1
                and c.y >= v.y and c.y <= v.y + (v.h or 1) - 1
            if covers and not seen[v] and v ~= caster and v.side ~= caster.side
                and (v.alive or v.lastAttacker == caster) then
                seen[v] = true
                if fire then r.fire = true end
                if Combat.unitGap(caster, v) >= PrideElites.FAR then r.far = true end
                r.struck[v] = r.struck[v] or {}
                r.struck[v][caster] = true
                local n = 0
                for _ in pairs(r.struck[v]) do n = n + 1 end
                if n >= 2 then r.together = true end
            end
        end
    end
end

-- Record that `actor` ended a turn: a body of the asked side that ended it off the tile it began on moved.
function PrideElites.noteTurnEnd(t, bearer, actor)
    local r = t.record
    if not (r and actor and asked(t, bearer, actor)) then return end
    if actor.turnStartX and (actor.x ~= actor.turnStartX or actor.y ~= actor.turnStartY) then r.moved = true end
end

local function nameOf(u) return (u and u.char and u.char.name) or "It" end

-- Deal the next riddle to `bearer`, off the fight's own seed and never the same one twice running, and
-- show it: a log line and a badge naming it.
function PrideElites.pose(combat, t, bearer)
    local Combat = require("models.combat")
    local Status = require("models.status")
    local pool = {}
    for _, r in ipairs(PrideElites.RIDDLES) do
        if not (t.riddle and t.riddle.id == r.id) then pool[#pool + 1] = r end
    end
    local riddle = pool[Combat.roll(combat, #pool)]
    t.riddle, t.record = riddle, newRecord()
    Status.apply(combat, bearer, riddle.status, { applier = bearer })
    Combat.logEvent(combat, "status", string.format("%s asks: %s before its next turn.", nameOf(bearer),
        riddle.text), bearer)
    return riddle
end

-- Judge the round that just closed and deal the next. Met: the reward (the Sphinx is Answered and can be
-- hurt until its next turn; a company's bearer gains Empowered). Failed: the asker heals its share, if it
-- has one. Returns whether the riddle was met.
function PrideElites.judge(combat, t, bearer)
    local Combat = require("models.combat")
    local Status = require("models.status")
    local Trait = require("models.trait")
    local riddle, met = t.riddle, false
    Status.remove(combat, bearer, PrideElites.ANSWERED)
    if riddle then
        Status.remove(combat, bearer, riddle.status)
        met = riddle.met(t.record or newRecord()) and true or false
        if met then
            Status.apply(combat, bearer, Trait.param(t, "reward", PrideElites.ANSWERED), { applier = bearer })
            Combat.logEvent(combat, "status", string.format("The riddle is met. %s gains %s.", nameOf(bearer),
                (Status.defs[Trait.param(t, "reward", PrideElites.ANSWERED)] or {}).name or "its answer"), bearer)
        else
            local share = Trait.param(t, "failHeal", PrideElites.FAIL_HEAL)
            if share > 0 then
                local max = Combat.unreservedMax(bearer.char, "health")
                Combat.applyHeal(combat, bearer, math.max(1, math.floor(max * share + 0.5)))
            end
            Combat.logEvent(combat, "status", string.format("The riddle is not met.%s",
                share > 0 and (" " .. nameOf(bearer) .. " heals.") or ""), bearer)
        end
    end
    PrideElites.pose(combat, t, bearer)
    return met
end

-- ------------------------------------------------------------------------------------------- the Phoenix

PrideElites.EMBER = "character_phoenix_ember"
PrideElites.PHOENIX = "character_phoenix"
PrideElites.REBORN_DAMAGE = 3 -- per death, on status_reborn's stacks

-- Felled, the Phoenix burns down to an Ember on its own tile (the nearest free one if something stands
-- there). It leaves no corpse: there is nothing of it left to raise but the Ember. Returns the Ember.
function PrideElites.layEmber(combat, phoenix)
    local Combat = require("models.combat")
    local Character = require("models.character")
    local Status = require("models.status")
    local x, y = phoenix.x, phoenix.y
    if not Combat.footprintFree(combat, 1, 1, x, y) then x, y = Combat.openTileNear(combat, x, y) end
    if not x then return nil end
    phoenix.corpse = nil
    local ember = Combat.addUnit(combat, Character.instantiate(PrideElites.EMBER), phoenix.side, x, y,
        { timeless = true })
    ember.phoenixLevel = phoenix.char and phoenix.char.level
    ember.phoenixDeaths = (phoenix.phoenixDeaths or 0) + 1
    Status.apply(combat, ember, "status_rekindling")
    Combat.logEvent(combat, "action", string.format("%s burns down to an Ember. Break it before it rises.",
        nameOf(phoenix)), ember)
    return ember
end

-- The Ember's clock ran out: it catches, and the Phoenix stands on its tile at full health, wearing Reborn
-- once for every time it has died. Returns the risen Phoenix.
function PrideElites.rise(combat, ember)
    local Combat = require("models.combat")
    local Character = require("models.character")
    local Growth = require("models.growth")
    local Status = require("models.status")
    if not (ember and ember.alive) then return nil end
    local x, y, side = ember.x, ember.y, ember.side
    local level, deaths = ember.phoenixLevel, ember.phoenixDeaths or 1
    Combat.dismiss(combat, ember, "The Ember catches.")
    local char = Character.instantiate(PrideElites.PHOENIX)
    if level and level > 1 then Growth.resolve(char, level) end
    local phoenix = Combat.addUnit(combat, char, side, x, y)
    phoenix.phoenixDeaths = deaths
    Status.apply(combat, phoenix, "status_reborn", { magnitude = deaths, applier = phoenix })
    Combat.logEvent(combat, "action", string.format("%s rises again, whole, %d Damage the stronger.",
        nameOf(phoenix), PrideElites.REBORN_DAMAGE * deaths), phoenix)
    return phoenix
end

-- ------------------------------------------------------------------------------------------- the Tower-Giant

PrideElites.AMBITION = "status_ambition"
PrideElites.CRASH_PER_STACK = 6 -- pre-mitigation impact damage, per stack of Ambition

-- How far the fall reaches and how hard it lands, for `stacks` of Ambition: every tile within
-- 1 + floor(stacks / 3) (the square ring Combat.unitsNear measures), for 6 a stack. Nothing at 0.
function PrideElites.crashOf(stacks)
    stacks = stacks or 0
    if stacks <= 0 then return 0, 0 end
    return 1 + math.floor(stacks / 3), PrideElites.CRASH_PER_STACK * stacks
end

return PrideElites
