-- AFFIXES: one or two bodies in an ordinary fight carry a named twist -- Armored, Swift, Vampiric -- read
-- off a mark on the token and a line on its hover (approved 2026-10-24, "variety in the fight itself").
--
-- WHAT ONE IS MADE OF, and why it needs no new balance surface. An affix blueprint (data/affixes/) declares
-- the fields a piece of gear already declares, and each folds in at the seam gear already uses:
--   bonus / resist / maxBonus   flat stats, folded beside the meal and the relics (Combat's applyUnitPassives)
--   traits                      existing trait ids, lent whole (Thorned is trait_thorns, Volatile the imp's)
--   statuses                    opened at the bell: { { id, magnitude, duration } } (Affix.open)
--   on<Hook>                    a trait hook written on the affix itself, for the four rules no trait
--                               carried yet (Vampiric, Warded, Rallying, Splitting, Hexing). Run through
--                               Trait's own dispatch as an item-less instance (Affix.traitInstances), so
--                               Sunder silences it, the re-entry latch guards it, and nothing in
--                               models/grade.lua has to weigh a trait that sits on no shelf.
--
-- WHO GETS ONE is decided at the board (Affix.assign, called by Arena.build), because only the board knows
-- the roster: the dressing stamped on the map names WHICH affixes and how many (models/dressing.lua), and the
-- arena hands them to the sturdiest one-tile bodies that are not the objective's mark. Stamped onto
-- `arena.enemies[i].affix`, carried onto the unit by Combat.new (Affix.stamp).
--
-- Pure: no love.graphics, so it loads under the headless tests.
local Registry = require("models.registry")

local Affix = {}

Affix.defs = Registry.load("data/affixes", "data.affixes")

-- The ids, sorted, so a seed deals the same affix off the same list on every machine.
function Affix.ids()
    local ids = {}
    for id in pairs(Affix.defs) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
end

-- HOW OFTEN AN ORDINARY FIGHT CARRIES ONE: a quarter on floor one, three quarters by floor ten, flat
-- after. One line, so the curve is retuned in one place.
Affix.CHANCE_LO, Affix.CHANCE_HI, Affix.CHANCE_FLOOR = 0.25, 0.75, 10

function Affix.chanceAt(floor)
    local t = math.min(1, math.max(0, ((floor or 1) - 1) / (Affix.CHANCE_FLOOR - 1)))
    return Affix.CHANCE_LO + t * (Affix.CHANCE_HI - Affix.CHANCE_LO)
end

-- HOW MANY BODIES: one, two from floor six down, never more.
Affix.TWO_FROM = 6
Affix.MAX = 2

function Affix.countAt(floor)
    return ((floor or 1) >= Affix.TWO_FROM) and 2 or 1
end

-- ---------------------------------------------------------------------------
-- Who wears it
-- ---------------------------------------------------------------------------

local function isMark(id, obj)
    if not (obj and id) then return false end
    local names = {}
    for _, m in ipairs(obj.targets or {}) do names[#names + 1] = m end
    if obj.target then names[#names + 1] = obj.target end
    if obj.escape and obj.escape.who then names[#names + 1] = obj.escape.who end
    for _, m in ipairs(names) do
        if id == m or (type(id) == "string" and id:sub(1, #m + 1) == m .. "@") then return true end
    end
    return false
end

-- Can this body carry an affix at all? A real one-tile combatant: not an object (an egg, a totem), not a
-- body that takes no turns, not a boss's footprint, and not the body the objective is decided on -- an
-- assassination's mark that splits, or a runner that is Swift, would be a different fight from the one
-- the banner names.
function Affix.canWear(id, obj)
    local def = require("models.character").defs[id]
    if not def then return false end
    if def.race == "object" or def.timeless then return false end
    local fp = def.footprint
    if fp and ((fp.w or 1) > 1 or (fp.h or 1) > 1) then return false end
    if isMark(id, obj) then return false end
    return true
end

-- Hand `affixes` (a list of ids) to the bodies in `enemies` (Arena.build's seated list, { id, x, y }):
-- the highest-tier eligible bodies first, then seat order. Deterministic -- no draw -- so the same roster
-- always affixes the same bodies. Returns how many were stamped.
function Affix.assign(enemies, affixes, objective)
    if not (enemies and affixes and #affixes > 0) then return 0 end
    local Character = require("models.character")
    local cands = {}
    for i, e in ipairs(enemies) do
        if Affix.canWear(e.id, objective) then cands[#cands + 1] = { i = i, e = e } end
    end
    local function tier(c)
        local def = Character.defs[c.e.id]
        return (def and def.tier) or 0
    end
    table.sort(cands, function(a, b)
        local ta, tb = tier(a), tier(b)
        if ta ~= tb then return ta > tb end
        return a.i < b.i
    end)
    local n = 0
    for k = 1, math.min(#affixes, #cands, Affix.MAX) do
        if Affix.defs[affixes[k]] then
            cands[k].e.affix = affixes[k]
            n = n + 1
        end
    end
    return n
end

-- Carry the arena's stamps onto the live units. Matched by seat and body id rather than by list position,
-- so a caller that built its unit list some other way still lands each affix on the body it was meant for.
function Affix.stamp(combat, arena)
    if not (combat and arena and arena.enemies) then return end
    for _, e in ipairs(arena.enemies) do
        if e.affix then
            for _, u in ipairs(combat.units) do
                if u.side == "enemy" and not u.affix and u.x == e.x and u.y == e.y
                    and u.char and u.char.id == e.id then
                    u.affix = e.affix
                    break
                end
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- What it does
-- ---------------------------------------------------------------------------

function Affix.def(unit)
    return unit and unit.affix and Affix.defs[unit.affix] or nil
end

-- The flat-stat bag Combat's applyUnitPassives folds beside the relics: { bonus, resist, maxBonus }, or nil.
function Affix.bag(unit)
    local def = Affix.def(unit)
    if not (def and (def.bonus or def.resist or def.maxBonus)) then return nil end
    return { bonus = def.bonus, resist = def.resist, maxBonus = def.maxBonus }
end

-- The trait instances an affix lends (Trait.attach appends them): each lent trait id, plus the affix
-- itself when it carries a hook of its own. A fresh list every attach, so a once-a-fight latch
-- (`stacks`) starts at nothing in every fight.
local HOOKS = { "onCombatStart", "onDamaged", "onDeath", "onStatusApplied", "onBlowLanded",
                "onAnyTurnStart", "onTurnStart", "onTurnEnd", "onAnyTurnEnd", "onAnyDeath" }

function Affix.traitInstances(unit)
    local def = Affix.def(unit)
    if not def then return {} end
    local Trait = require("models.trait")
    local out = {}
    for _, id in ipairs(def.traits or {}) do
        if Trait.defs[id] then out[#out + 1] = Trait.instantiate(id, nil) end
    end
    for _, hook in ipairs(HOOKS) do
        if def[hook] then
            out[#out + 1] = { id = unit.affix, name = def.name, def = def, stacks = 0 }
            break
        end
    end
    return out
end

-- The statuses it opens the fight wearing. Called at the bell (Combat.openBattle), after every trait is
-- attached -- so a Warded body does not shrug off its own Haste (a buff is no debuff anyway).
function Affix.open(combat)
    local Status = require("models.status")
    for _, u in ipairs((combat and combat.units) or {}) do
        local def = u.alive and Affix.def(u)
        for _, s in ipairs((def and def.statuses) or {}) do
            Status.apply(combat, u, s.id, { magnitude = s.magnitude, duration = s.duration })
        end
    end
end

return Affix
