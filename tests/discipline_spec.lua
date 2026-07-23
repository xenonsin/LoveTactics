-- Tests for the discipline contract (docs/classes.md "Disciplines"; slate in docs/disciplines-plan.md).
-- A discipline is a shop taxonomy: arity is the whole distinction (1 parent = subclass, 2 = multiclass),
-- and the gate is earned advancement. This pins the structural rules so a malformed blueprint, a reused
-- gate quest, or a mistagged item fails the build rather than vanishing silently.
--
-- Deliberately NOT asserted yet: that every `exemplar` character exists. ~27 of them are pending
-- content (see the "pending" markers in data/disciplines/*.lua) and asserting them now would fail the
-- build on work that is scheduled, not wrong -- a missing exemplar costs a quest its intended body,
-- which is a stand-in, not a dead gate.
--
-- Capstone quests USED to be exempt for the same reason and are not any more: all 21 are on disk, and
-- unlike an exemplar a missing gate quest is fatal rather than cosmetic (see the capstone case below).
-- What is pinned: structure, both tiers of gate quest, the no-reuse rule, the satisfiable-gate rule,
-- and the item tagging invariant.
--
-- Pure logic, headless.

local Discipline = require("models.discipline")
local Item = require("models.item")
local Vendor = require("models.vendor")
local Quest = require("models.quest")

local tests = {}

-- The sponsoring vendor's class for a quest id, or nil.
local function questClass(questId)
    local q = Quest.defs[questId]
    local sponsor = q and q.sponsor
    local v = sponsor and Vendor.defs[sponsor]
    return v and v.class
end

tests[#tests + 1] = { name = "every discipline is well-formed (name, 1-2 real parents, exemplar, gate)", fn = function()
    for id, def in pairs(Discipline.defs) do
        assert(type(def.name) == "string" and def.name ~= "", id .. ": missing name")
        local n = #(def.classes or {})
        assert(n == 1 or n == 2, id .. ": must have 1 or 2 parent classes, has " .. n)
        for _, c in ipairs(def.classes) do
            assert(Item.CLASSES[c], id .. ": unknown parent class " .. tostring(c))
        end
        assert(type(def.exemplar) == "string" and def.exemplar ~= "", id .. ": missing exemplar")
        assert(type(def.requiredQuests) == "table" and #def.requiredQuests >= 1, id .. ": needs requiredQuests")
    end
end }

tests[#tests + 1] = { name = "a subclass gate is one existing quest in its parent vendor's line", fn = function()
    for id, def in pairs(Discipline.defs) do
        if #def.classes == 1 then
            local parent = def.classes[1]
            for _, q in ipairs(def.requiredQuests) do
                assert(Quest.defs[q], id .. ": subclass gate quest '" .. q .. "' does not exist")
                assert(questClass(q) == parent,
                    id .. ": gate quest '" .. q .. "' is sponsored by a " .. tostring(questClass(q))
                    .. " vendor, not " .. parent)
            end
        end
    end
end }

-- The capstones. A gate quest that does not exist is not a soft "pending" state -- `Player.hasCompleted`
-- returns false for an id nothing defines, forever, so `Discipline.isUnlocked` can never return true and
-- the discipline's whole shelf is dead stock. All 21 multiclass capstones are on disk now; this is what
-- keeps them there.
--
-- Sponsor is deliberately NOT asserted to match a parent the way the subclass rule above does: a
-- capstone stages a fusion, and either parent's vendor is a legitimate host for it (the Ninja's is the
-- Undercroft, the Battlemage's the Arcanum). Existence is the contract; whose board it sits on is a
-- staging call.
tests[#tests + 1] = { name = "a multiclass capstone gate names a quest that exists", fn = function()
    for id, def in pairs(Discipline.defs) do
        if #def.classes == 2 then
            for _, q in ipairs(def.requiredQuests) do
                assert(Quest.defs[q], id .. ": capstone gate quest '" .. q .. "' does not exist -- the "
                    .. "discipline can never unlock and its shelf is unreachable")
            end
        end
    end
end }

tests[#tests + 1] = { name = "a multiclass gate is satisfiable: each parent has at least one subclass", fn = function()
    for id, def in pairs(Discipline.defs) do
        if #def.classes == 2 then
            for _, parent in ipairs(def.classes) do
                assert(#Discipline.subclassesOf(parent) >= 1,
                    id .. ": parent '" .. parent .. "' has no subclass, so its gate can never be met")
            end
        end
    end
end }

tests[#tests + 1] = { name = "no quest gates two disciplines (the no-reuse rule)", fn = function()
    local seen = {}
    for id, def in pairs(Discipline.defs) do
        for _, q in ipairs(def.requiredQuests) do
            assert(not seen[q], "quest '" .. q .. "' gates both " .. tostring(seen[q]) .. " and " .. id)
            seen[q] = id
        end
    end
end }

tests[#tests + 1] = { name = "every discipline-tagged item's class is one of its discipline's parents", fn = function()
    for id, item in pairs(Item.defs) do
        if item.discipline then
            local def = Discipline.defs[item.discipline]
            assert(def, id .. ": unknown discipline '" .. tostring(item.discipline) .. "'")
            local ok = false
            for _, parent in ipairs(def.classes) do
                if item.class == parent then ok = true; break end
            end
            assert(ok, id .. ": class '" .. tostring(item.class) .. "' is not a parent of discipline '"
                .. item.discipline .. "'")
        end
    end
end }

tests[#tests + 1] = { name = "growthClasses tallies all parents of a discipline item, else the bare class", fn = function()
    -- A multiclass item grows BOTH parents (ninja = rogue x mage).
    local g = Discipline.growthClasses({ class = "rogue", discipline = "ninja" })
    local set = {}
    for _, c in ipairs(g) do set[c] = true end
    assert(set.rogue and set.mage, "a ninja item should tally both rogue and mage")
    assert(#g == 2, "a ninja item should tally exactly two classes")
    -- A plain classed item grows its one class.
    local gp = Discipline.growthClasses({ class = "fighter" })
    assert(#gp == 1 and gp[1] == "fighter", "a plain item tallies its single class")
    -- A class-less, discipline-less item (a natural weapon, a torch) tallies nothing.
    assert(#Discipline.growthClasses({}) == 0, "a class-less item tallies nothing")
end }

return tests
