-- The quest board as a LADDER: can a player actually climb it, and does every quest point at things
-- that exist? These are the invariants an audit keeps re-deriving by hand, pinned so they stop being
-- something anyone has to remember.
--
-- The reachability case is the important one, and it is not hypothetical. The Colosseum shipped
-- soft-locked: `arena_debut` + `warlord_keep` paid 85 reputation, `blood_in_the_sand` gated at rank 3
-- (100), and there was no way to earn the fifteen points that unlocked the quest that earned the rest.
-- docs/story.md calls that "a shipping bug, not a design note" and it survived for a long time because
-- nothing computed it. Now something does.
--
-- The model is deliberately conservative: for each quest, sum the reputation of that sponsor's quests
-- gated STRICTLY EARLIER (lower prestige, or equal prestige and a lower rank), and require it to cover
-- this quest's rank threshold. Strictly-earlier is the pessimistic reading -- a player might in
-- practice also have cleared a same-gate sibling first -- and pessimistic is what a lock check wants.
--
-- Pure logic, headless.

local Quest = require("models.quest")
local Item = require("models.item")
local Character = require("models.character")
local Vendor = require("models.vendor")

local function rankOf(def) return (def.requiredRep and def.requiredRep.rank) or 1 end
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
        name = "every reputation gate is reachable from quests gated strictly earlier",
        fn = function()
            local bad = {}
            for sponsor, list in pairs(bySponsor()) do
                local vdef = Vendor.defs[sponsor]
                local ranks = (vdef and vdef.ranks) or {}
                for _, e in ipairs(list) do
                    local need = ranks[rankOf(e.def)] or 0
                    if need > 0 then
                        local available = 0
                        for _, other in ipairs(list) do
                            local earlier = prestigeOf(other.def) < prestigeOf(e.def)
                                or (prestigeOf(other.def) == prestigeOf(e.def)
                                    and rankOf(other.def) < rankOf(e.def))
                            -- A quest cannot pay for its own gate.
                            if earlier and other.id ~= e.id then
                                available = available + (other.def.rewardRep or 0)
                            end
                        end
                        if available < need then
                            bad[#bad + 1] = string.format("%s (%s): needs %d, only %d earnable earlier",
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
        -- A sponsor whose whole line cannot reach its own top rank can never sell its rank-4 relic or
        -- offer its general. Checked separately from the per-quest gate above because a line can be
        -- individually reachable at every rung and still stop short of the last one.
        name = "every vendor line can reach its own top rank on authored quests alone",
        fn = function()
            local bad = {}
            for sponsor, list in pairs(bySponsor()) do
                local vdef = Vendor.defs[sponsor]
                local ranks = (vdef and vdef.ranks) or {}
                local top = ranks[#ranks] or 0
                local total = 0
                for _, e in ipairs(list) do
                    -- The general itself pays out AFTER it is gated, so it cannot fund its own gate.
                    if rankOf(e.def) < #ranks then total = total + (e.def.rewardRep or 0) end
                end
                if total < top then
                    bad[#bad + 1] = string.format("%s: %d reputation available below rank %d, needs %d",
                        sponsor, total, #ranks, top)
                end
            end
            table.sort(bad)
            assert(#bad == 0, table.concat(bad, "; "))
        end,
    },
    {
        -- THE LINE IS A CHAIN. A sin line runs in authored order: each slot names the one before it in
        -- `requiredQuests`, and prestige gates only the line's ENTRY (its vendor's door). That is what
        -- makes a line a story rather than a pile -- slot 7's reveal cannot be read before slot 5's
        -- discovery, which was exactly what a pure prestige gate allowed.
        --
        -- Walked BACKWARDS from each general, because the general is the one end that is unambiguous:
        -- follow the single prerequisite until the sponsor changes, and the walk must lay out that
        -- line's ten slots with no repeats. A cycle shows up as a repeat; a break shows up as a short
        -- walk; a fork shows up as a prerequisite count that is not one.
        --
        -- The Cathedral's head deliberately steps outside its own line (`haunted_mill` waits on
        -- `arena_debut`, so the church opens after the debut on the sand) -- which is why the walk
        -- stops on a sponsor change rather than on running out of prerequisites.
        name = "each sin line is an unbroken chain of ten, walked back from its general",
        fn = function()
            local generals = {}
            for id, def in pairs(Quest.defs) do
                if def.gateHint then generals[#generals + 1] = id end
            end
            assert(#generals == 7, "expected seven generals, found " .. #generals)
            table.sort(generals)

            for _, generalId in ipairs(generals) do
                local sponsor = Quest.defs[generalId].sponsor
                local seen, walk, cursor = {}, {}, generalId
                while cursor and Quest.defs[cursor] and Quest.defs[cursor].sponsor == sponsor do
                    assert(not seen[cursor],
                        sponsor .. ": the chain loops back on " .. cursor)
                    seen[cursor] = true
                    walk[#walk + 1] = cursor

                    local req = Quest.defs[cursor].requiredQuests
                    if not req then break end
                    assert(#req == 1, cursor .. " has " .. #req
                        .. " prerequisites; a slot in a line names exactly one")
                    cursor = req[1]
                end
                assert(#walk == 10, sponsor .. ": walking back from " .. generalId
                    .. " covers " .. #walk .. " slots, not 10 (" .. table.concat(walk, " <- ") .. ")")
            end
        end,
    },
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
    {
        -- The finale's keys. Each of the seven generals must exist AND carry a `gateHint`, because the
        -- hint the board shows is keyed off the completed quest rather than off the relic it dropped
        -- (models/quest.lua's gateHints) -- a general without one silently costs the player a fragment
        -- of the Gate's location with nothing to show it went missing.
        name = "the Gate Below's seven prerequisites all exist and carry a gateHint",
        fn = function()
            local gate = Quest.defs.quest_the_gate_below
            assert(gate, "quest_the_gate_below is missing")
            local req = gate.requiredQuests or {}
            assert(#req == 7, "the Gate Below wants seven keys, not " .. #req)
            for _, id in ipairs(req) do
                local def = Quest.defs[id]
                assert(def, "the Gate Below requires '" .. id .. "', which does not exist")
                assert(def.gateHint, id .. " is a Gate Below prerequisite with no gateHint")
                assert(def.rewardItems and #def.rewardItems > 0, id .. " is a general that drops nothing")
            end
        end,
    },
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
