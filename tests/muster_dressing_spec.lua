-- A DRESSED FIGHT IS RATED AS ONE (models/muster.lua's Muster.DRESSING, measured by tools/dressing_cost.lua).
--
-- An affixed body, a condition or a rolled objective (models/dressing.lua) changes a fight without changing
-- its roster, and every reading of a fight was taken off the roster alone -- the marker's band, the Run Away
-- odds, the walk-off gate. What is held here: the dressing multiplies the roster's worth by exactly the
-- table's factor, per affixed body and only where the roster can seat it; the cell door states/game.lua
-- rates a marker through carries the stamped dressing; and the margin every one of the three readings is
-- taken off moves with it.
local Arena = require("models.arena")
local Descent = require("models.descent")
local Dressing = require("models.dressing")
local Affix = require("models.affix")
local Encounter = require("models.encounter")
local Flee = require("models.flee")
local Muster = require("models.muster")

local FLOOR = 3

local function ctx()
    return { depth = FLOOR, enemyLevel = Descent.dangerLevel({ floor = FLOOR }) }
end

-- The roster Muster.encounter rates, resolved the way it resolves it.
local function rosterOf(def)
    local c = ctx()
    local ids = Arena.resolveComposition(def.composition, c)
    return Arena.clampComposition(ids, Arena.enemyCap({ encounterKind = def.kind, encounterCap = def.enemyCap }))
end

local function wearers(ids)
    local n = 0
    for _, id in ipairs(ids) do if Affix.canWear(id, nil) then n = n + 1 end end
    return n
end

-- The first ordinary (dressable) fight whose rated roster passes `want`.
local function findFight(want)
    local ids = {}
    for id, def in pairs(Encounter.defs) do
        if Dressing.eligible({ id = id, kind = def.kind }) then ids[#ids + 1] = id end
    end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local def = Encounter.get(id)
        local ok, roster = pcall(rosterOf, def)
        if ok and #roster > 0 and Muster.encounter(def, ctx()) > 0 and want(roster) then return def, roster, id end
    end
end

local function rated(def, dressing)
    local c = ctx()
    c.dressing = dressing
    return Muster.encounter(def, c)
end

local function near(a, b) return math.abs(a - b) < 1e-6 * math.max(1, math.abs(b)) end

-- The heaviest dressing the table prices, as a dressing table and its factor.
local function heaviest()
    local best, bestF = nil, 1
    for id, f in pairs(Muster.DRESSING.condition) do
        if f > bestF then best, bestF = { condition = id }, f end
    end
    for id, f in pairs(Muster.DRESSING.affix) do
        if f > bestF then best, bestF = { affixes = { id } }, f end
    end
    return best, bestF
end

return {
    { name = "every affix, condition and rolled kind the game deals has a measured row", fn = function()
        for _, id in ipairs(Affix.ids()) do
            assert(type(Muster.DRESSING.affix[id]) == "number", "no measured price for " .. id)
        end
        for _, id in ipairs(require("models.condition").ids()) do
            assert(type(Muster.DRESSING.condition[id]) == "number", "no measured price for " .. id)
        end
        for _, kind in ipairs(Dressing.KINDS) do
            assert(type(Muster.DRESSING.objective[kind]) == "number", "no measured price for " .. kind)
        end
        local _, f = heaviest()
        assert(f > 1, "the measurement found at least one dressing that makes a fight harder")
    end },

    { name = "a dressed fight rates higher than the same fight undressed, by the table's factor", fn = function()
        local def = findFight(function(r) return wearers(r) >= 2 end)
        assert(def, "an ordinary fight with two bodies that can wear an affix")
        local bare = rated(def, nil)
        assert(near(rated(def, {}), bare), "an empty dressing is worth nothing")
        for id, f in pairs(Muster.DRESSING.affix) do
            assert(near(rated(def, { affixes = { id } }), bare * f), id .. " multiplies the worth by its row")
        end
        for id, f in pairs(Muster.DRESSING.condition) do
            assert(near(rated(def, { condition = id }), bare * f), id .. " multiplies the worth by its row")
        end
        -- Two affixed bodies apply the multiplier per body; the condition multiplies on top.
        local ids = Affix.ids()
        local a, b = Muster.DRESSING.affix[ids[1]], Muster.DRESSING.affix[ids[2]]
        local cond = require("models.condition").ids()[1]
        local c = Muster.DRESSING.condition[cond]
        assert(near(rated(def, { affixes = { ids[1], ids[2] }, condition = cond }), bare * a * b * c),
            "two affixes and a condition multiply together")
    end },

    { name = "an affix is priced only on a body that can wear it", fn = function()
        local def = findFight(function(r) return wearers(r) == 1 end)
        if not def then return end -- no single-wearer roster on this floor: nothing to hold
        local bare = rated(def, nil)
        local ids = Affix.ids()
        local a = Muster.DRESSING.affix[ids[1]]
        assert(near(rated(def, { affixes = { ids[1], ids[2] } }), bare * a),
            "one body that can wear an affix carries one, so only the first is priced")
    end },

    { name = "a rolled objective is priced where the roster carries it, and not where it falls back", fn = function()
        for _, kind in ipairs(Dressing.KINDS) do
            local f = Muster.DRESSING.objective[kind]
            local yes = findFight(function(r) return Dressing.compatible(kind, r) end)
            if yes then
                assert(near(rated(yes, { objective = kind }), rated(yes, nil) * f), kind .. " multiplies by its row")
            end
            local no = findFight(function(r) return not Dressing.compatible(kind, r) end)
            if no then
                assert(near(rated(no, { objective = kind }), rated(no, nil)),
                    kind .. " on a roster that cannot carry it is a kill-all, and rated as one")
            end
        end
    end },

    { name = "the cell door the map rates through reads the stamped dressing", fn = function()
        local def, _, id = findFight(function(r) return wearers(r) >= 1 end)
        local dressing, f = heaviest()
        local floor = ctx()
        local bare = Muster.encounterCell({ encounter = { id = id, kind = def.kind } }, floor)
        local dressed = Muster.encounterCell({ encounter = { id = id, kind = def.kind, dressing = dressing } }, floor)
        assert(near(bare, Muster.encounter(def, ctx())), "an undressed cell rates as its blueprint")
        assert(near(dressed, bare * f), "a dressed cell rates at the table's factor")
        assert(Muster.encounterCell({}, floor) == nil, "an empty cell has nothing to rate")
    end },

    { name = "the Run Away odds and the walk-off gate move with the dressed worth", fn = function()
        local def = findFight(function(r) return wearers(r) >= 1 end)
        local dressing, f = heaviest()
        local bare, dressed = rated(def, nil), rated(def, dressing)
        assert(dressed > bare, "the heaviest dressing raises the worth")

        -- A company worth exactly twice the bare fight may walk it off; dressed, the same company may not.
        local ours = bare * Muster.WALK_OVER / 100
        assert(Muster.canWalkOver(Muster.margin(ours, bare)), "twice the bare worth is a walk-over")
        assert(not Muster.canWalkOver(Muster.margin(ours, dressed)),
            "the dressing takes the walk-off away from the company that had it")

        -- An even fight undressed is a worse escape dressed: the odds read the same margin.
        local even = bare
        local before, after = Flee.chance(Muster.margin(even, bare)), Flee.chance(Muster.margin(even, dressed))
        assert(before == Flee.EVEN, "an even bare fight quotes the even odds")
        local want = Flee.chance(100 / f)
        assert(after == want and after < before,
            string.format("dressed, the odds fall to %d%% (got %d%%, factor %.2f)", want, after, f))
    end },
}
