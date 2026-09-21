-- DROP ASSIGN: deal the rift's catalogue out onto the bodies that can hand it over.
--
--     & "E:\LOVE\lovec.exe" . drop-assign              -- the proposal, per circle
--     & "E:\LOVE\lovec.exe" . drop-assign full         -- ...every body and its list
--     & "E:\LOVE\lovec.exe" . drop-assign apply        -- write `drops` onto the blueprints
--
-- WHY THIS IS DERIVED AND NOT AUTHORED. 429 items over ~83 bodies is not a design decision taken 429
-- times; it is one ranking applied 429 times, and this repo already settled how that goes -- the grade
-- sets the slot (tools/grade_report.lua), the grade sets the depth (tools/drop_tier.lua), and neither
-- of those is a list somebody typed. Hand-assigning would also be unauditable: the question that
-- matters is "can this item be reached", and only a pass that walks placement can answer it
-- (tools/drop_report.lua). So the assignment is computed, reported, and only written when told.
--
-- THE THREE RULES IT DEALS BY, in order:
--
--   CLASS   an item goes to a body of its own class, because that is the line the player is farming.
--           A crossing's stock (an earned class) goes to a body of either PARENT, since no body is
--           authored as a crossing and the parent houses are what the bench bills anyway.
--   DEPTH   an item goes to a body whose own rung is near its `unlockLevel`. A body's rung is its tier
--           spread up the class ladder (see rungOf) -- chaff at the top of the stair, a boss at the
--           bottom -- so the deep catalogue lands on the deep bodies and a floor-one mook cannot hand
--           over floor-eight kit even before Spoils.depthOf refuses it.
--   SPREAD  no body takes more than TARGET_LIST, and the lightest eligible body wins each deal, so a
--           circle's stock lands evenly instead of piling onto whichever body sorted first.
--
-- WHAT IT REFUSES TO DEAL, and each refusal is somebody else's rule rather than this pass's:
--
--   CREATURES     docs/bestiary.md: bodied chaff carry priced, lootable gear; creature chaff carry
--                 natural weapons only. A wolf is not a Beastmaster. Read off `kind`, and the demon
--                 and undead question the doc leaves open is answered by GEAR_KINDS below.
--   BOSSES        a general already pays an authored piece off Descent.DROPS. Two reward routes on one
--                 body makes the authored one the consolation prize (models/identify.lua makes the
--                 same argument about husks on a stair guardian).
--   BOUND         nailed to one grid by definition.
--   SIGNATURES    an exemplar's own relic rides its bearer (tools/drop_tier.lua's own carve-out).
--   PRICED        it has a counter. That is its answer (docs/shelf.md).
--
-- WHAT IT KEEPS RATHER THAN DEALS: `dropsPinned` on a body.
--
-- The deal is from scratch every time -- that is what makes it auditable -- so anything a HUMAN put on
-- a list is gone the next time this runs, silently, and the list still looks derived. It happened: the
-- Scale Hauberk is naga plate that the nagas do not WEAR (a naga already carries `lightning = -4`, and
-- the coat would double it), so it was authored onto the lancer's list as the only way the race's own
-- armour reaches a player at all -- and a re-deal took it off, because the coat is knight stock and no
-- rule here would ever seat it on a naga. `tests/naga_spec.lua` is what noticed.
--
-- A pin is that exception said out loud: the ids on `dropsPinned` are seated first, count against
-- TARGET_LIST, and are taken off the table so the deal cannot hand them to anybody else. Pin the thing
-- a body IS where the three rules below cannot see it; everything else is dealt.
--
-- Report first. Nothing is written until you say `apply`.

local Character = require("models.character")
local Class = require("models.class")
local Descent = require("models.descent")
local Item = require("models.item")
local Spoils = require("models.spoils")

local M = {}

-- HOW LONG A LIST MAY GET. Five: long enough that a body is known for more than one thing, short
-- enough to read on a card, and about what a Monster Hunter reward table runs. Shared with
-- tools/drop_report.lua's bill, which is where the figure was derived.
local TARGET_LIST = 5

-- WHICH BODIES CARRY GEAR AT ALL, and this table is the answer to the question docs/bestiary.md leaves
-- open. The doc names "humans and humanoids" against "beasts, summons, constructs" and says nothing
-- about demons or undead -- which is 9 of the 83 placed bodies and moves every list length.
--
-- Demons and undead are IN, and the reading is the doc's own: the split is about whether a thing has
-- hands and a shelf, not about whether it is alive. A demon champion carries worked steel and reads as
-- an army rather than a spawn list (docs/bestiary.md says exactly that of the demons); a barrow-wight
-- is a body that was buried with its kit. A beast, an elemental, a construct and a prop have no shelf
-- to have bought from, and their natural weapons are unpriced and `noSteal` already.
local GEAR_KINDS = { humanoid = true, demon = true, undead = true }

local function sortedKeys(t)
    local out = {}
    for k in pairs(t) do out[#out + 1] = k end
    table.sort(out)
    return out
end

local function hasTag(def, tag)
    for _, t in ipairs(def.tags or {}) do if t == tag then return true end end
    return false
end

-- class -> sin, off the vendor blueprints rather than typed here, so the seven houses and the seven
-- circles cannot drift apart. models/descent.lua already keys a circle to a vendor; this is the other
-- half of the same join.
local sinByClass
local function sinOfClass(class)
    if not sinByClass then
        sinByClass = {}
        local Registry = require("models.registry")
        local vendors = Registry.load("data/vendors", "data.vendors")
        for _, def in pairs(vendors) do
            if def.class and def.sin then sinByClass[def.class] = def.sin end
        end
    end
    return class and sinByClass[class] or nil
end

-- A BODY'S RUNG on the same 1..CLASS_LEVEL_CAP ladder an item's unlockLevel sits on.
--
-- Spread off `tier`, the bestiary's four bands (docs/bestiary.md: chaff, line, elite, boss), because
-- that is the only depth signal a character blueprint carries and it was never designed for this --
-- it emerged from sorting the catalogue by health. Four bands over eight rungs is two rungs a band,
-- which is coarse and honest: this decides WHICH HALF of the ladder a body deals from, and
-- Spoils.depthOf still refuses anything the floor itself cannot reach.
local function rungOf(def)
    local tier = math.max(1, math.min(4, def.tier or 2))
    local span = Class.CLASS_LEVEL_CAP / 4
    return math.max(1, math.ceil(tier * span))
end

-- Every body that may be dealt to: placed by some encounter, carrying gear, not a boss.
local function eligibleBodies(placed)
    local out = {}
    for _, charId in ipairs(sortedKeys(placed)) do
        local def = Character.defs[charId]
        if def and GEAR_KINDS[def.kind or ""] and not def.boss then
            local list = {}
            for _, id in ipairs(def.dropsPinned or {}) do
                if Item.defs[id] then list[#list + 1] = id end
            end
            out[#out + 1] = {
                id = charId,
                def = def,
                class = def.class,
                sin = sinOfClass(def.class),
                rung = rungOf(def),
                list = list,
            }
        end
    end
    return out
end

-- Every item this pass is allowed to deal. See the header for each refusal's owner.
local function dealable()
    local out = {}
    for _, id in ipairs(sortedKeys(Item.defs)) do
        local def = Item.defs[id]
        local priced = def.price and def.price > 0
        if def.unlockLevel and not def.bound and not priced and not hasTag(def, "signature")
            and def.class and def.class ~= "creature" then
            out[#out + 1] = { id = id, def = def, depth = Spoils.depthOf(def) }
        end
    end
    return out
end

-- Which bodies may carry `item`: its own class, or -- for a crossing -- either parent's.
local function bodiesForClass(bodies, class)
    local want = {}
    if Class.defs[class] and not Class.isRoot(class) then
        for _, parent in ipairs(Class.parents(class)) do want[parent] = true end
    else
        want[class] = true
    end
    local out = {}
    for _, body in ipairs(bodies) do
        if body.class and want[body.class] then out[#out + 1] = body end
    end
    return out
end

-- The deal, in TWO PASSES, and the split is the whole of what makes a list worth reading.
--
-- One pass cannot do it. Dealing deepest-first and seating each item on the nearest-rung body with
-- room clusters by construction: the deep items are gone by the time a mid-rung body comes up, so it
-- takes five of whatever band happens to be current. The first cut of this produced an Archer holding
-- five items all at depth 6 -- a list with nothing on it worth a second trip, and a list that makes
-- models/spoils.lua's depth weighting describe nothing, since every entry weighs the same.
--
--   PASS 1  every body takes ONE standout: the deepest piece of its class still unclaimed. This is the
--           thing the body is known for, and the thing its weighting makes rare.
--   PASS 2  the remaining slots fill from what is left, nearest-rung as before, and never as deep as
--           that body's own standout -- so the standout stays the deepest thing on its list and the
--           rarity ladder is real rather than nominal.
--
-- Bodies take their standout DEEPEST-RUNG FIRST, so the deepest kit lands on the bodies that can
-- legally hold it before a shallow body takes it off the table (Spoils.depthOf still refuses anything
-- the floor cannot reach, but a piece seated too shallow is a piece nobody meets at the right depth).
local function assign()
    local placed = require("tools.drop_report").placement()
    local bodies = eligibleBodies(placed)
    local items = dealable()

    -- Deepest first. A deep item has the fewest bodies that can legally hold it, so dealing it while
    -- the lists are still empty is the difference between "no room" and "no candidate" -- the same
    -- reason a packing pass places its largest pieces first.
    table.sort(items, function(a, b)
        if a.depth ~= b.depth then return a.depth > b.depth end
        return a.id < b.id
    end)

    -- PASS 0: the pins. Off the table before anything is dealt, so the deal cannot hand a pinned
    -- piece to a second body -- and a pin deeper than its body's own rung IS that body's standout,
    -- which is what stops pass 2 filling a list with something rarer than the thing it was pinned for.
    local taken = {}
    for _, body in ipairs(bodies) do
        for _, id in ipairs(body.list) do
            taken[id] = true
            local depth = Spoils.depthOf(Item.defs[id])
            if depth > body.rung and depth > (body.standoutDepth or 0) then
                body.standoutDepth = depth
            end
        end
    end

    -- PASS 1: one standout each.
    local byRung = {}
    for _, body in ipairs(bodies) do byRung[#byRung + 1] = body end
    table.sort(byRung, function(a, b)
        if a.rung ~= b.rung then return a.rung > b.rung end
        return a.id < b.id
    end)
    for _, body in ipairs(byRung) do
        for _, item in ipairs(items) do -- already deepest-first
            if body.standoutDepth then break end
            if not taken[item.id] and item.depth > body.rung and #body.list < TARGET_LIST then
                local ok = false
                for _, cand in ipairs(bodiesForClass({ body }, item.def.class)) do
                    if cand == body then ok = true end
                end
                if ok then
                    taken[item.id] = true
                    body.list[#body.list + 1] = item.id
                    body.standoutDepth = item.depth
                    break
                end
            end
        end
    end

    -- PASS 2: fill the rest, and never at or past the body's own standout.
    local orphans = {}
    for _, item in ipairs(items) do
        if not taken[item.id] then
            local candidates = bodiesForClass(bodies, item.def.class)
            local best, bestScore
            for _, body in ipairs(candidates) do
                if #body.list < TARGET_LIST
                    and (not body.standoutDepth or item.depth < body.standoutDepth) then
                    -- Nearest rung wins; a shorter list breaks the tie, which spreads the stock.
                    local score = math.abs(body.rung - item.depth) * 100 + #body.list
                    if not bestScore or score < bestScore then best, bestScore = body, score end
                end
            end
            if best then
                taken[item.id] = true
                best.list[#best.list + 1] = item.id
            else
                orphans[#orphans + 1] = item
            end
        end
    end

    -- Shallowest first within a list, so a body's own entries read as a ladder -- and so the standout,
    -- which is the deepest, sits at the bottom where the eye finishes.
    for _, body in ipairs(bodies) do
        table.sort(body.list, function(a, b)
            local da, db = Spoils.depthOf(Item.defs[a]), Spoils.depthOf(Item.defs[b])
            if da ~= db then return da < db end
            return a < b
        end)
    end

    return bodies, orphans, items
end

-- ---------------------------------------------------------------------------
-- Writing
-- ---------------------------------------------------------------------------

-- Stamp a `drops = { ... }` field onto a character blueprint, replacing any existing one. Inserted
-- directly after `startingItems` where there is one (the two belong beside each other -- what a body
-- carries and what it is known for), else before the closing brace.
local function write(charId, list)
    local path = "data/characters/" .. charId .. ".lua"
    local file = io.open(path, "r")
    if not file then return false, "missing" end
    local src = file:read("*a")
    file:close()

    local block = "    drops = {\n"
    for _, id in ipairs(list) do block = block .. '        "' .. id .. '",\n' end
    block = block .. "    },\n"

    if src:find("\n    drops = {") then
        src = src:gsub("\n    drops = %b{},\n", "\n" .. block, 1)
    else
        local anchor = src:find("\n    startingItems = ")
        if anchor then
            local stop = src:find("\n    %a", anchor + 1) or src:find("\n}", anchor + 1)
            src = src:sub(1, stop) .. block .. src:sub(stop + 1)
        else
            src = src:gsub("\n}%s*$", "\n" .. block .. "}\n", 1)
        end
    end

    local out = io.open(path, "w")
    if not out then return false, "readonly" end
    out:write(src)
    out:close()
    return true
end

-- ---------------------------------------------------------------------------

function M.run(args)
    args = args or {}
    local mode = args[1]
    local doApply = mode == "apply" or args[2] == "apply"

    local bodies, orphans, items = assign()

    local dealt, filled = 0, 0
    local bySin = {}
    for _, body in ipairs(bodies) do
        dealt = dealt + #body.list
        if #body.list > 0 then filled = filled + 1 end
        local key = body.sin or "(no circle)"
        bySin[key] = bySin[key] or { bodies = 0, items = 0 }
        bySin[key].bodies = bySin[key].bodies + 1
        bySin[key].items = bySin[key].items + #body.list
    end

    print(string.rep("=", 78))
    print("DROP ASSIGN — dealing the rift's catalogue onto the bodies that can hand it over")
    print(string.rep("=", 78))
    print(string.format("  %d items dealable · %d bodies eligible · %d dealt · %d orphaned",
        #items, #bodies, dealt, #orphans))
    print(string.format("  %d of %d bodies came away with a list (target %d each)",
        filled, #bodies, TARGET_LIST))
    print("")

    for _, sin in ipairs(Descent.SINS) do
        local row = bySin[sin.id]
        if row then
            print(string.format("    %-10s %2d bodies  %3d items  %4.1f per list",
                sin.id, row.bodies, row.items,
                row.bodies > 0 and row.items / row.bodies or 0))
        end
    end
    local loose = bySin["(no circle)"]
    if loose then
        print(string.format("    %-10s %2d bodies  %3d items   <- classed to no house",
            "(none)", loose.bodies, loose.items))
    end

    if mode == "full" then
        print("")
        print(string.rep("-", 78))
        for _, body in ipairs(bodies) do
            if #body.list > 0 then
                print(string.format("  %-40s rung %d  %s", body.id, body.rung,
                    body.sin or "-"))
                for _, id in ipairs(body.list) do
                    print(string.format("      %-44s depth %d", id,
                        Spoils.depthOf(Item.defs[id])))
                end
            end
        end
    end

    if #orphans > 0 then
        print("")
        print(string.rep("=", 78))
        print(string.format("ORPHANED — %d items no eligible body could take", #orphans))
        print(string.rep("=", 78))
        print("  Every one of these is an item with no route once the price band is deleted. The fix is")
        print("  bodies of that class at that depth, not a longer list (docs/drops.md's bill).")
        print("")
        local byClass = {}
        for _, item in ipairs(orphans) do
            local key = item.def.class or "(none)"
            byClass[key] = (byClass[key] or 0) + 1
        end
        for _, class in ipairs(sortedKeys(byClass)) do
            print(string.format("    %-24s %3d  (circle: %s)", class, byClass[class],
                tostring(sinOfClass(class) or "-")))
        end
    end

    print("")
    if not doApply then
        print("  Dry run. Add `apply` to write these lists onto the blueprints.")
        return
    end

    local wrote, failed = 0, 0
    for _, body in ipairs(bodies) do
        if #body.list > 0 then
            local ok = write(body.id, body.list)
            if ok then wrote = wrote + 1 else failed = failed + 1 end
        end
    end
    print(string.format("  APPLIED: %d blueprints written, %d failed.", wrote, failed))
    print("  Re-run `. drop-report` to confirm the routes moved off the band.")
end

return M
