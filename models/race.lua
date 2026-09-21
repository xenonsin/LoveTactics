-- RACE: what a body IS, one axis above what it does.
--
-- The Mere arrived asking for a class of its own and the answer was that a naga is not a job. A naga
-- knight and a naga mage are both nagas, and neither fact tells you the other -- which is the
-- definition of a second axis. `class` was the only taxonomy a body had that carried rules, so it was
-- being used to say something class cannot say.
--
-- THE HARD LINE, AND IT IS THE WHOLE DISCIPLINE OF THIS FILE: a race carries RULES and a FIXED stat
-- line. It may never carry a growth table and it may never stock a shelf.
--
--   fixed        a growth table is what a body BECAME; a race is what it IS. That border is the whole
--                of "not a class", and it is the reason this folds at instantiate -- once, into the
--                base stats -- rather than per level like models/growth.lua.
--   bounded      Race.STAT_BUDGET, below. A race that could out-give a class would be a class.
--   no shelf     a race names no vendor, no discipline and no rung. Class.isRoot answers the shelf
--                question and always will; nothing here is consulted by models/vendor.lua.
--
-- The version of this system every other game ships -- "+2 Strength, -2 Intelligence" -- is the one
-- this rule exists to refuse. `tier` already holds the same discipline for the same reason (a declared
-- label, never a multiplier), and the blueprint headers in data/characters/ spend twenty lines apiece
-- defending authored numbers that a silent racial addend would quietly invalidate.
--
-- `kind` ROLLS UP FROM HERE rather than sitting beside it. Every race declares the kind the item rules
-- read (docs/bestiary.md's creature/bodied split, the demon's holy line, the discipline gate), and no
-- blueprint declares one any more. Before this, `kind` was authored 167 times and had been a GUESS
-- before that -- tools/char_compose.lua inferred it from words in the id and defaulted to "most
-- portraitless enemies are people", which made every wolf in the folder a humanoid as far as the code
-- was concerned. Two authored ledgers of one fact drift; one is derived from the other or they are the
-- same field.
--
-- Plain data plus lookups, no love.* at require time, so it loads under the headless suite.

local Registry = require("models.registry")

local Race = {}

Race.defs = Registry.load("data/races", "data.races")

-- WHAT A RACE MAY DECLARE, and each entry names its own read site.
--
-- A CLOSED SET, for the reason models/terrain.lua's BONUS_KEYS is closed and learned the expensive
-- way: a generic bag that accepts every key and reads two of them printed "+2 Defense bonus" to the
-- player and moved no number in the fight, for years, because nothing had authored the key yet. A key
-- in this list is a promise some function keeps; a key absent from it is a typo.
--
-- ORDERED, one list rather than a set plus a display order, so the two cannot drift.
Race.FIELDS = {
    { key = "name",   read = "every readout that says what a body is" },
    { key = "kind",   read = "Character.instantiate -- the coarse split every item rule already uses" },
    { key = "tags",   read = "Combat.isAquatic (`swim`), and the grid scan every innate rule after it uses" },
    { key = "resist", read = "Combat.applyUnitPassives, folded exactly as a creature's innate table is" },
    { key = "bonus",  read = "Character.instantiate -- a FIXED addend on the base stat line" },
    { key = "grants", read = "Character.instantiate -- bound items seeded into the body's grid" },
    { key = "playable", read = "tests/race_spec.lua -- may the player's roster wear this" },
    { key = "description", read = "docs and the bestiary; never mechanical" },
}

local FIELD_SET = {}
for _, entry in ipairs(Race.FIELDS) do FIELD_SET[entry.key] = entry.read end
function Race.readsField(key)
    return FIELD_SET[key]
end

-- THE CEILING ON A RACIAL STAT LINE: two points of absolute magnitude, summed over every stat it
-- names. The naga spends exactly that (`movement -1, speed +1`), which is deliberate -- the budget was
-- set at what the first race needed and not a point above it, so the second race to want more has to
-- argue for it here rather than quietly take it.
--
-- Absolute magnitude, so a line cannot buy itself room by pairing a large gift with a large cost. A
-- race that wants to be dramatic has `tags`, `resist` and `grants` to be dramatic with, all three of
-- which are rules rather than numbers and none of which silently re-tunes a time-to-kill band.
Race.STAT_BUDGET = 2

-- The blueprint for `id`, or nil. Never falls back to a default: a body whose race does not exist is a
-- hole in the data, and a hole that resolved to "human" would put a wolf on a shelf.
function Race.get(id)
    return id and Race.defs[id] or nil
end

-- What KIND of body this race is -- the field every item rule in the bestiary splits on. Nil for an
-- unknown race, which is what makes a missing or misspelled `race` fail loudly at the spec rather than
-- quietly at the shelf.
function Race.kindOf(id)
    local def = Race.get(id)
    return def and def.kind or nil
end

-- May the player's roster wear this race? True unless the blueprint says otherwise, exactly as
-- Class.isPlayable reads its own field -- so "a body nobody can be" is a declaration rather than an
-- omission. A beast is not playable; a naga is (docs/nagas.md leaves the companion door open, and the
-- axis is only worth having if the things with classes have it).
function Race.isPlayable(id)
    local def = Race.get(id)
    return def ~= nil and def.playable ~= false
end

-- The fixed stat line this race adds, as { stat = amount }. Always a table, never nil, so a caller may
-- iterate it without asking first.
--
-- EXPOSED RATHER THAN ONLY FOLDED, and that is the clause S1 of the review asked for: the fold happens
-- inside Character.instantiate, where every body that ever plays the game sees it -- but a TOOL that
-- reads raw blueprints does not instantiate anything. tools/balance_rescale.lua moves a body's health
-- to land it inside its time-to-kill band, and a stat line it cannot see is a body it re-tunes against
-- the wrong number, with nothing turning red. This is the seam such a tool reads.
function Race.statBonus(id)
    local def = Race.get(id)
    return (def and def.bonus) or {}
end

-- The bound items this race puts in a body's grid. Always a list.
--
-- A RACE GRANTS WHAT IT IS MADE OF, and this is deliberately not a second implementation of anything.
-- The naga's `swim` lives on utility_naga_coils, in the grid, where Combat.isAquatic already looks --
-- so the predicate never learns a second place to search, the player can SEE why that body swims on
-- the same surface they read everything else about it, and the demon's own crown stops being authored
-- into sixteen separate grids.
--
-- The cost is named rather than hidden: a granted item takes a grid cell. That is a real price for a
-- racial rule, and it is the same price the demons have always paid.
function Race.grantsOf(id)
    local def = Race.get(id)
    return (def and def.grants) or {}
end

-- Every race that declares `tag`, as a sorted list of ids. For reports and specs; nothing in the fight
-- path asks this (a fight asks the unit's grid, through Combat.isAquatic).
function Race.withTag(tag)
    local out = {}
    for id, def in pairs(Race.defs) do
        for _, t in ipairs(def.tags or {}) do
            if t == tag then out[#out + 1] = id; break end
        end
    end
    table.sort(out)
    return out
end

return Race
