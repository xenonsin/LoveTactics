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

-- The display name of discipline `id` ("Ninja"), or nil when the id is absent or unknown. The single
-- place the UI turns a stored id into words, so every surface that names an item's discipline -- the
-- tooltip's row, the shop shelf, the forge -- says it the same way, and a stale id on an item prints
-- nothing rather than leaking a raw slug into the panel.
function Discipline.displayName(id)
    local def = id and Discipline.defs[id]
    if not def then return nil end
    return def.name or id
end

-- The growth paths a use of `item` should tally toward (models/growth.lua, which reads these as keys
-- into data/growth/<id>.lua). A discipline is ITS OWN growth path: a discipline item tallies the
-- discipline id, so a build leaning on Ninja stock grows on data/growth/ninja.lua -- a blend the two
-- parent tables cannot express, and the mechanical half of "each discipline is its own thing." A plain
-- item tallies its single `class`. Empty for a class-less, discipline-less item (a natural weapon).
--
-- This SUPERSEDES the older "a discipline item tallies both parent classes" rule. It could because
-- every discipline now has a growth table of its own (there is one file per discipline, enforced by
-- tests/discipline_spec.lua); before, a discipline had no table and had to borrow its parents'. The
-- unlock gating means the path is naturally earned -- a character cannot grow toward a discipline
-- until that discipline's stock is on the shelf to carry.
--
-- Named `growthClasses` (not `growthPaths`) because the caller and the growth model still think in
-- one vocabulary of tally keys, and a discipline id is just another key alongside the seven classes.
function Discipline.growthClasses(item)
    if not item then return {} end
    if item.discipline and Discipline.defs[item.discipline] then
        return { item.discipline }
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

-- The disciplines a vendor of `class` should ANNOUNCE to `player`: unlocked, not yet announced, and
-- carrying `class` as one of their parents (so their stock lands on this shelf). Sorted for a stable
-- order when several came due at once. This is the shop-open hook in states/hub.lua -- it names the
-- newly earned disciplines whose gear just appeared on the rack the player is standing at.
--
-- A multiclass has two parents; it will match at either vendor, but `hasAnnouncedDiscipline` is keyed
-- per discipline, so the first shop opened claims it and the second does not repeat.
function Discipline.pendingAnnouncements(player, class)
    local Player = require("models.player")
    local out = {}
    for id, def in pairs(Discipline.defs) do
        local onThisShelf = false
        for _, parent in ipairs(def.classes or {}) do
            if parent == class then onThisShelf = true end
        end
        if onThisShelf and Discipline.isUnlocked(player, id)
            and not Player.hasAnnouncedDiscipline(player, id) then
            out[#out + 1] = id
        end
    end
    table.sort(out)
    return out
end

return Discipline
