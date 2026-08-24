-- The quest board as a LADDER: can a player actually climb it, and does every quest point at things
-- that exist? These are the invariants an audit keeps re-deriving by hand, pinned so they stop being
-- something anyone has to remember.
--
-- The reachability case is the important one, and it is not hypothetical. The Colosseum once shipped
-- soft-locked: a mid-line quest was gated on a standing there was no way to earn, because nothing
-- computed whether the gate could be reached from the quests gated below it. Now something does.
--
-- A vendor's standing is now simply how many of its quests you have finished (Quest.sponsorProgress),
-- so a quest's gate is `requiredSponsorQuests = { vendor, count }`. The model is deliberately
-- conservative: for each quest, COUNT that sponsor's quests gated STRICTLY EARLIER (lower prestige, or
-- equal prestige and a lower count), and require that many to be at least this quest's threshold.
-- Strictly-earlier is the pessimistic reading -- a player might in practice also have cleared a
-- same-gate sibling first -- and pessimistic is what a lock check wants.
--
-- Pure logic, headless.

local Quest = require("models.quest")
local Item = require("models.item")
local Character = require("models.character")
local Vendor = require("models.vendor")

local function countOf(def) return (def.requiredSponsorQuests and def.requiredSponsorQuests.count) or 0 end
local function prestigeOf(def) return def.requiredPrestige or 1 end

-- Quests grouped by sponsor, ignoring the unsponsored finale (the Gate Below answers to no vendor).
local function bySponsor()
    local out = {}
    for id, def in pairs(Quest.defs) do
        if def.sponsor then
            out[def.sponsor] = out[def.sponsor] or {}
            table.insert(out[def.sponsor], { id = id, def = def })
        end
    end
    return out
end

-- Every character id a quest's objective can put on the board.
local function referencedCharacters(def)
    local names = {}
    local o = def.map and def.map.objective
    if not o then return names end
    if type(o.composition) == "function" then
        -- Compositions scale with prestige; sample the range rather than one point, since a blueprint
        -- can be introduced by a `math.floor` branch that only fires at high prestige.
        for _, p in ipairs({ 1, 3, 5, 10 }) do
            local ok, list = pcall(o.composition, { prestige = p })
            if ok and type(list) == "table" then
                for _, c in ipairs(list) do names[#names + 1] = c end
            end
        end
    end
    for _, c in ipairs(o.allies or {}) do names[#names + 1] = c end
    if o.win then
        if o.win.target then names[#names + 1] = o.win.target end
        if o.win.protect then names[#names + 1] = o.win.protect end
    end
    return names
end

return {
    {
        name = "every sponsor-quest gate is reachable from quests gated strictly earlier",
        fn = function()
            local bad = {}
            for sponsor, list in pairs(bySponsor()) do
                for _, e in ipairs(list) do
                    local need = countOf(e.def)
                    if need > 0 then
                        local available = 0
                        for _, other in ipairs(list) do
                            local earlier = prestigeOf(other.def) < prestigeOf(e.def)
                                or (prestigeOf(other.def) == prestigeOf(e.def)
                                    and countOf(other.def) < countOf(e.def))
                            -- A quest cannot count toward its own gate.
                            if earlier and other.id ~= e.id then
                                available = available + 1
                            end
                        end
                        if available < need then
                            bad[#bad + 1] = string.format("%s (%s): needs %d quests done, only %d gated earlier",
                                e.id, sponsor, need, available)
                        end
                    end
                end
            end
            table.sort(bad)
            assert(#bad == 0, "soft-locked quest gate(s): " .. table.concat(bad, "; "))
        end,
    },
    {
        -- A sponsor whose whole line cannot reach its own top gate can never sell its top-tier relic or
        -- offer its general. Checked separately from the per-quest gate above because a line can be
        -- individually reachable at every rung and still stop short of the last one.
        name = "every vendor line can reach its own top gate on authored quests alone",
        fn = function()
            local bad = {}
            for sponsor, list in pairs(bySponsor()) do
                local top = 0
                for _, e in ipairs(list) do top = math.max(top, countOf(e.def)) end
                if top > 0 then
                    -- The general itself sits AT the top gate, so it cannot count toward reaching it.
                    local below = 0
                    for _, e in ipairs(list) do
                        if countOf(e.def) < top then below = below + 1 end
                    end
                    if below < top then
                        bad[#bad + 1] = string.format("%s: %d quests gated below the top gate of %d, needs %d",
                            sponsor, below, top, top)
                    end
                end
            end
            table.sort(bad)
            assert(#bad == 0, table.concat(bad, "; "))
        end,
    },
    -- ("each sin line is an unbroken chain of ten, walked back from its general" stood here. It found
    -- the seven generals by their gateHint and walked each line backwards through requiredQuests,
    -- asserting the chain was ten long and unbroken. There are no lines: a house asks for its opener and
    -- its discipline gates, six pieces of work with no order between them but the slot number
    -- (models/errand.lua). The chain it walked is the field errands drop at the door.)
    {
        -- Prestige may gate a line's entry; it must not gate its running order. Two quests of the same
        -- sponsor that sit in the same chain therefore share a prestige requirement -- if a later slot
        -- asked for more, the chain would stall behind a number again and the rule above would be
        -- decorative.
        name = "a line's slots share one prestige gate, so only the chain orders them",
        fn = function()
            local byS = {}
            for id, def in pairs(Quest.defs) do
                if def.requiredQuests and def.sponsor then
                    for _, prev in ipairs(def.requiredQuests) do
                        local p = Quest.defs[prev]
                        if p and p.sponsor == def.sponsor then
                            local a, b = p.requiredPrestige or 1, def.requiredPrestige or 1
                            if a ~= b then
                                byS[#byS + 1] = string.format("%s (P%d) follows %s (P%d)",
                                    id, b, prev, a)
                            end
                        end
                    end
                end
            end
            table.sort(byS)
            assert(#byS == 0, "prestige still orders a line: " .. table.concat(byS, "; "))
        end,
    },
    {
        -- Two quests handing over the same unique means one of them silently pays nothing the second
        -- time (Quest.complete has no cross-quest guard, and Player.grantItem would just mint a second
        -- copy of something the fiction says is one of a kind).
        name = "no item is granted by two different quests",
        fn = function()
            local from, bad = {}, {}
            for id, def in pairs(Quest.defs) do
                for _, item in ipairs(def.rewardItems or {}) do
                    from[item] = from[item] or {}
                    table.insert(from[item], id)
                end
            end
            for item, quests in pairs(from) do
                if #quests > 1 then
                    table.sort(quests)
                    bad[#bad + 1] = item .. " <- " .. table.concat(quests, ", ")
                end
            end
            table.sort(bad)
            assert(#bad == 0, "item(s) granted by more than one quest: " .. table.concat(bad, "; "))
        end,
    },
    {
        -- An objective naming a blueprint that does not exist is a crash at battle start, not a
        -- degraded fight -- and it is invisible until someone plays that exact quest at that exact
        -- prestige, which is why the composition is sampled across the range.
        name = "every character a quest objective names exists",
        fn = function()
            local bad = {}
            for id, def in pairs(Quest.defs) do
                local seen = {}
                for _, c in ipairs(referencedCharacters(def)) do
                    if not Character.defs[c] and not seen[c] then
                        seen[c] = true
                        bad[#bad + 1] = id .. " -> " .. c
                    end
                end
            end
            table.sort(bad)
            assert(#bad == 0, "quest(s) naming a missing character blueprint: " .. table.concat(bad, "; "))
        end,
    },
    -- ("the Gate Below's seven prerequisites all exist and carry a gateHint" stood here. The Gate
    -- Below is deleted and so are the seven slot-10 quests it named; the ending is the Hollow Crown at
    -- the bottom of a descent and tests/ending_spec.lua guards it.)
    {
        -- Every quest points at a real vendor, and the sponsor gate is satisfiable: a quest whose
        -- prestige requirement is below its own vendor's building unlock can never appear, because
        -- Quest.available checks both.
        name = "every quest names a real sponsor it could actually be offered by",
        fn = function()
            local Building = require("models.building")
            local bad = {}
            for id, def in pairs(Quest.defs) do
                if def.sponsor then
                    if not Vendor.defs[def.sponsor] then
                        bad[#bad + 1] = id .. ": unknown sponsor '" .. def.sponsor .. "'"
                    else
                        local opens = Building.vendorUnlockPrestige(def.sponsor)
                        if prestigeOf(def) < opens then
                            bad[#bad + 1] = string.format("%s: requiredPrestige %d but %s opens at %d",
                                id, prestigeOf(def), def.sponsor, opens)
                        end
                    end
                end
            end
            table.sort(bad)
            assert(#bad == 0, table.concat(bad, "; "))
        end,
    },
}
