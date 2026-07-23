-- Discipline logic. Blueprints live in data/disciplines/<id>.lua (see docs/classes.md, "Disciplines",
-- and the authoring slate in docs/disciplines-plan.md).
--
-- A discipline is a shop taxonomy like `class`: unlocking it adds a locked deeper cut of items to its
-- parent vendor shelf(es). Arity is the whole distinction -- one parent is a subclass, two is a
-- multiclass -- and the gate is earned advancement: a multiclass unlocks only once the player already
-- holds a subclass of EACH parent (which is what opens its capstone quest).
--
-- Pure logic (no love.graphics), so it loads under the headless tests.

local Registry = require("models.registry")

local Discipline = {}

Discipline.defs = Registry.load("data/disciplines", "data.disciplines")

-- The parent classes of a discipline id (its `classes` list). {} for an unknown id.
function Discipline.parents(id)
    local def = id and Discipline.defs[id]
    return (def and def.classes) or {}
end

-- Arity: 1 = subclass, 2 = multiclass, 0 = unknown id.
function Discipline.arity(id)
    return #Discipline.parents(id)
end

-- The classes a use of `item` should tally toward growth (models/growth.lua). A discipline item
-- tallies ALL of its discipline's parent classes -- a Ninja weapon grows both rogue AND mage -- which
-- is what makes a multiclass item advance the fusion rather than one half of it. A plain item tallies
-- its single `class`. Empty for a class-less, discipline-less item (a natural weapon, a torch).
function Discipline.growthClasses(item)
    if not item then return {} end
    if item.discipline and Discipline.defs[item.discipline] then
        return Discipline.parents(item.discipline)
    end
    if item.class then return { item.class } end
    return {}
end

-- Every subclass (arity-1 discipline) whose single parent is `class`.
function Discipline.subclassesOf(class)
    local out = {}
    for id, def in pairs(Discipline.defs) do
        if def.classes and #def.classes == 1 and def.classes[1] == class then
            out[#out + 1] = id
        end
    end
    return out
end

-- Is discipline `id` unlocked for `player`? All its requiredQuests are completed, AND -- if it is a
-- multiclass -- the player already holds at least one unlocked subclass of EACH parent (earned
-- advancement). Recursion is shallow and terminating: a subclass has no discipline prerequisites.
function Discipline.isUnlocked(player, id)
    local def = id and Discipline.defs[id]
    if not def then return false end

    local completed = (player and player.completedQuests) or {}
    for _, q in ipairs(def.requiredQuests or {}) do
        if not completed[q] then return false end
    end

    if #(def.classes or {}) >= 2 then
        for _, parent in ipairs(def.classes) do
            local held = false
            for _, subId in ipairs(Discipline.subclassesOf(parent)) do
                if Discipline.isUnlocked(player, subId) then held = true; break end
            end
            if not held then return false end
        end
    end

    return true
end

-- The set { disciplineId = true } of every discipline currently unlocked for `player`. Vendor.stock
-- takes this bare set so that module stays player-free (the same shape as its `rank`/`recipes` args).
function Discipline.unlockedSet(player)
    local set = {}
    for id in pairs(Discipline.defs) do
        if Discipline.isUnlocked(player, id) then set[id] = true end
    end
    return set
end

return Discipline
