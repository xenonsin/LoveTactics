-- DROP REPORT: can a body actually pay this item, and which body is it?
--
--     & "E:\LOVE\lovec.exe" . drop-report                -- the ledger
--     & "E:\LOVE\lovec.exe" . drop-report unreachable    -- only what nothing pays
--     & "E:\LOVE\lovec.exe" . drop-report queued         -- only what sits past the end of a boss queue
--     & "E:\LOVE\lovec.exe" . drop-report bosses         -- what a general can now let go of
--     & "E:\LOVE\lovec.exe" . drop-report bodies         -- the placement census on its own
--
-- WHY THIS EXISTS, and why it had to be built BEFORE the per-body drop lists rather than after.
--
-- docs/shelf.md states the obligation this answers: "a shelf GUARANTEES an item is reachable; a drop
-- table does not. Reachability stopped being structural and became statistical the day this landed, and
-- any item whose honest answer is 'not at the depths people play' is content that does not exist."
-- Nothing has ever walked that. tools/drop_tier.lua decides how deep a thing falls at; tools/grade_report
-- decides what it is worth. Neither asks whether any body in the game ever hands one over.
--
-- IT MEASURES PLACEMENT RATHER THAN READING AUTHORING, and that distinction is the whole tool. An item
-- named on a body's list is not reachable unless some encounter seats that body, and an encounter does
-- not seat a body unless its `condition` passes somewhere on the calendar. So the census is taken by
-- sweeping Encounter.pool over real contexts and resolving each blueprint's own `composition` -- the same
-- call the overworld makes -- rather than by grepping ids out of the files. 56 of the 154 character
-- blueprints turn out never to be placed at all, which a read of the data cannot see.
--
-- THE FOUR ROUTES an item can reach a player by, and they are not equal:
--
--   drops     an authored per-body list (`drops` on the character blueprint). What a body is KNOWN
--             for, and the only route a player can aim at on purpose.
--   carried   the body is holding one, so the carried pool can hand it over (models/spoils.lua's
--             CARRIED_BIAS). Incidental rather than authored, but real and connected: you took his axe.
--   boss      Descent.DROPS -- a lieutenant's or a general's list. WALKED UNOWNED-FIRST, so a long list
--             is a QUEUE and position is reachability: the 21st entry needs 21 separate descents to that
--             circle. That is what QUEUE_REACH below measures against.
--   band      the depth-banded random draw. A PERMANENT route and the catalogue's long tail -- not
--             every item is meant to come off a body (docs/drops.md). Deleting it was decided in
--             review and then reversed once the per-body pass showed what total coverage costs, so
--             read "band only" as how much of the catalogue no body is known for: a quality figure
--             rather than a backlog.
--
-- Read nothing into an item appearing under several routes; the report prints the best one it has and
-- counts the rest, because what matters is whether a player can go and get it on purpose.
--
-- Pure reporting. Writes nothing, ever -- there is no `apply`, because what to do about a hole here is
-- an authoring decision and not a number this tool could compute.

local Character = require("models.character")
local Class = require("models.class")
local Descent = require("models.descent")
local Encounter = require("models.encounter")
local Item = require("models.item")
local Spoils = require("models.spoils")

local M = {}

-- HOW FAR DOWN A BOSS QUEUE COUNTS AS REACHED. A circle is visited once per descent, so an entry's
-- position IS a number of complete runs to that circle -- and a campaign that walks a given circle more
-- than six times is not a campaign, it is a farm. Deliberately generous: the point is to find the tail
-- that nobody will ever see, not to argue about the fifth entry.
local QUEUE_REACH = 6

-- WHAT A LEGIBLE LIST LOOKS LIKE, for the bill at the bottom. Five is the figure the catalogue already
-- lands on when it is spread over every placed body (429 / 98), and it is about what a Monster Hunter
-- reward table runs -- long enough that a body is known for more than one thing, short enough to read on
-- a card.
local TARGET_LIST = 5

-- The calendar the sweep walks. Six stops rather than forty: a `condition` gates on biome and a weight
-- gates on day, and no blueprint in the tree changes which BODIES it names more than once across a
-- decade of days -- it changes how many. Cheap enough to widen if one ever does.
local DAYS = { 1, 5, 10, 20, 30, 40 }

local function sortedKeys(t)
    local out = {}
    for k in pairs(t) do out[#out + 1] = k end
    table.sort(out)
    return out
end

-- Every biome a circle owns, plus nil for the encounters that gate on nothing.
local function biomes()
    local out, seen = {}, {}
    for _, sin in ipairs(Descent.SINS) do
        if sin.biome and not seen[sin.biome] then
            seen[sin.biome] = true
            out[#out + 1] = sin.biome
        end
    end
    return out
end

local function sinForBiome(b)
    for _, sin in ipairs(Descent.SINS) do
        if sin.biome == b then return sin.id end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- The placement census
-- ---------------------------------------------------------------------------

-- Which bodies can stand on a board at all, and in which circles. Returns
--   placed[charId] = { biomes = { [biome] = true }, ungated = bool, encounters = { id, ... } }
local function census()
    local placed = {}

    local function record(charId, biome, encId)
        local row = placed[charId]
        if not row then
            row = { biomes = {}, ungated = false, encounters = {} }
            placed[charId] = row
        end
        if biome then row.biomes[biome] = true else row.ungated = true end
        if not row.encounters[encId] then
            row.encounters[encId] = true
            row.encounters[#row.encounters + 1] = encId
        end
    end

    local function resolve(def, ctx)
        local comp = def.composition
        if type(comp) == "table" then return comp end
        if type(comp) ~= "function" then return nil end
        local ok, list = pcall(comp, ctx)
        if ok and type(list) == "table" then return list end
        return nil
    end

    local grounds = biomes()
    grounds[#grounds + 1] = false -- the ungated sweep, run with no biome in the context

    for _, day in ipairs(DAYS) do
        for _, ground in ipairs(grounds) do
            local biome = ground or nil
            local ctx = { day = day, prestige = day, biome = biome }
            -- Encounter.pool applies each blueprint's own minPrestige and condition, so an encounter
            -- that never passes anywhere never contributes a body -- which is the measurement.
            local ok, pool = pcall(Encounter.pool, ctx)
            if ok and pool then
                for _, entry in ipairs(pool) do
                    local def = Encounter.get(entry.id)
                    local list = def and resolve(def, ctx)
                    for _, charId in ipairs(list or {}) do
                        if type(charId) == "string" then record(charId, biome, entry.id) end
                    end
                end
            end
        end
    end

    return placed
end

-- The census, for the pass that deals the catalogue out (tools/drop_assign.lua). Exported rather than
-- reimplemented there because "which bodies can stand on a board" must be ONE measurement: a deal made
-- against a wider census than the report grades would seat items on bodies the report then calls
-- unreachable, and the two passes would disagree in a way neither could show you.
function M.placement()
    return census()
end

-- ---------------------------------------------------------------------------
-- The routes
-- ---------------------------------------------------------------------------

-- Every item any placed body is holding, and who holds it.
local function carriedBy(placed)
    local out = {}
    for charId in pairs(placed) do
        local def = Character.defs[charId]
        for _, itemId in ipairs((def or {}).startingItems or {}) do
            out[itemId] = out[itemId] or {}
            out[itemId][#out[itemId] + 1] = charId
        end
        -- The route being built. No blueprint carries one yet; reading it now means the tool grades the
        -- authoring as it lands instead of needing a second pass afterwards.
        for _, itemId in ipairs((def or {}).drops or {}) do
            out[itemId] = out[itemId] or {}
            out[itemId].authored = true
            out[itemId][#out[itemId] + 1] = charId
        end
    end
    return out
end

-- Every item on a Descent.DROPS list, with the position it sits at and whose list it is.
local function bossQueue()
    local out = {}
    for _, sin in ipairs(Descent.SINS) do
        local set = Descent.DROPS[sin.id]
        for _, which in ipairs({ "minor", "general" }) do
            for pos, itemId in ipairs((set or {})[which] or {}) do
                -- First writer wins: an item on two lists is reached by the shallower queue.
                if not out[itemId] or out[itemId].pos > pos then
                    out[itemId] = { sin = sin.id, which = which, pos = pos }
                end
            end
        end
    end
    return out
end

-- Is this item in the depth-banded fallback pool at any depth the game reaches? That is the route the
-- per-body work deletes, so everything resting on it alone is the bill.
local function inBand(def)
    if def.bound then return false end
    local priced = def.price and def.price > 0
    if not (priced or def.dropTier) then return false end
    return Spoils.depthOf(def) <= Class.CLASS_LEVEL_CAP
end

-- The set this report is about: what the rift is supposed to be able to hand over. Priced stock has a
-- counter and is not this tool's business; bound kit is nailed to a grid by definition.
local function riftPool()
    local out = {}
    for id, def in pairs(Item.defs) do
        if def.dropTier and not def.bound then out[id] = def end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Printing
-- ---------------------------------------------------------------------------

local function rule(ch)
    print(string.rep(ch or "-", 78))
end

local function head(title)
    print("")
    rule("=")
    print(title)
    rule("=")
end

local function printCensus(placed)
    local kinds, gated, ungated, total = {}, {}, 0, 0
    for _, sin in ipairs(Descent.SINS) do gated[sin.id] = 0 end

    for charId, row in pairs(placed) do
        total = total + 1
        local def = Character.defs[charId]
        local kind = (def or {}).kind or "(no kind)"
        kinds[kind] = (kinds[kind] or 0) + 1
        if row.ungated then
            ungated = ungated + 1
        else
            for biome in pairs(row.biomes) do
                local sin = sinForBiome(biome)
                if sin then gated[sin] = gated[sin] + 1 end
            end
        end
    end

    local onDisk = 0
    for _ in pairs(Character.defs) do onDisk = onDisk + 1 end

    head("PLACEMENT — which bodies can stand on a board at all")
    print(string.format("  %d of %d character blueprints are placed by some encounter (%d never are)",
        total, onDisk, onDisk - total))
    print("")
    print("  by kind:")
    for _, kind in ipairs(sortedKeys(kinds)) do
        print(string.format("    %-12s %3d", kind, kinds[kind]))
    end
    print("")
    print("  bodies gated to one circle (by the encounter's biome condition):")
    for _, sin in ipairs(Descent.SINS) do
        print(string.format("    %-10s (%-10s) %3d", sin.id, sin.biome or "-", gated[sin.id]))
    end
    print(string.format("    %-23s %3d   <- appear on any floor, so no circle owns them",
        "ungated", ungated))

    return total, kinds
end

-- ---------------------------------------------------------------------------

function M.run(args)
    args = args or {}
    local mode = args[1]

    local placed = census()
    local carried = carriedBy(placed)
    local queue = bossQueue()
    local pool = riftPool()

    local placedTotal, kinds = printCensus(placed)
    if mode == "bodies" then return end

    -- Sort every item in the rift pool into the best route it has.
    local byRoute = { drops = {}, carried = {}, boss = {}, band = {}, none = {} }
    local queuedPast = {}

    for _, id in ipairs(sortedKeys(pool)) do
        local def = pool[id]
        local holders = carried[id]
        local q = queue[id]

        if holders and holders.authored then
            byRoute.drops[#byRoute.drops + 1] = id
        elseif holders then
            byRoute.carried[#byRoute.carried + 1] = id
        elseif q then
            byRoute.boss[#byRoute.boss + 1] = id
            if q.pos > QUEUE_REACH then
                queuedPast[#queuedPast + 1] = { id = id, q = q }
            end
        elseif inBand(def) then
            byRoute.band[#byRoute.band + 1] = id
        else
            byRoute.none[#byRoute.none + 1] = id
        end
    end

    local poolTotal = 0
    for _ in pairs(pool) do poolTotal = poolTotal + 1 end

    head("THE RIFT POOL — how each item reaches a player")
    print(string.format("  %d items carry a dropTier and are not bound.", poolTotal))
    print("")
    print(string.format("    %-22s %4d   %s", "drops (authored)", #byRoute.drops,
        "a body's own list"))
    print(string.format("    %-22s %4d   %s", "carried", #byRoute.carried,
        "a placed body is holding one"))
    print(string.format("    %-22s %4d   %s", "boss list", #byRoute.boss,
        "Descent.DROPS, walked unowned-first"))
    print(string.format("    %-22s %4d   %s", "BAND ONLY", #byRoute.band,
        "<- the random draw. This is the authoring worklist."))
    print(string.format("    %-22s %4d   %s", "NOTHING", #byRoute.none,
        "<- no route at all, at any depth"))

    if #queuedPast > 0 then
        head(string.format("QUEUED PAST REACH — position > %d on a list walked unowned-first", QUEUE_REACH))
        print(string.format("  A circle is visited once per descent, so a position IS a count of complete"))
        print(string.format("  runs to that circle. %d items sit past %d.", #queuedPast, QUEUE_REACH))
        print("")
        table.sort(queuedPast, function(a, b)
            if a.q.sin ~= b.q.sin then return a.q.sin < b.q.sin end
            return a.q.pos < b.q.pos
        end)
        for _, row in ipairs(queuedPast) do
            print(string.format("    %-10s %-8s #%-3d %s", row.q.sin, row.q.which, row.q.pos, row.id))
        end
    end

    if #byRoute.none > 0 and mode ~= "queued" then
        head("UNREACHABLE — nothing in the game hands these over")
        for _, id in ipairs(byRoute.none) do
            local def = pool[id]
            print(string.format("    %-44s tier %-2s class %s", id,
                tostring(def.dropTier), tostring(def.class)))
        end
    end

    -- R2-2's worklist: which entries a general could now let go of. An entry past the first that has
    -- picked up a body route is carried by two routes, and the boss QUEUE is the worse of the two --
    -- position is a count of complete descents to that circle. An entry with no other route must stay
    -- however deep in the queue it sits, because a queued item is still reachable and a deleted one is
    -- not (docs/shelf.md's reachability clause).
    if mode == "bosses" then
        head("BOSS LISTS — what the generals can now let go of")
        print("  Entry #1 is the authored relic and never moves: a circle is a two-piece set in the")
        print("  order it taught it (models/descent.lua). Everything behind it is overflow.")
        print("")
        local freed, stuck = 0, 0
        for _, sin in ipairs(Descent.SINS) do
            local set = Descent.DROPS[sin.id] or {}
            for _, which in ipairs({ "minor", "general" }) do
                local list = set[which] or {}
                for pos, itemId in ipairs(list) do
                    if pos > 1 then
                        local holders = carried[itemId]
                        local routed = holders and holders.authored
                        if routed then
                            freed = freed + 1
                            print(string.format("    FREE  %-10s %-8s #%-3d %s", sin.id, which, pos, itemId))
                        else
                            stuck = stuck + 1
                            print(string.format("    keep  %-10s %-8s #%-3d %s  (no body route)",
                                sin.id, which, pos, itemId))
                        end
                    end
                end
            end
        end
        print("")
        print(string.format("  %d entries can come off a boss list; %d must stay.", freed, stuck))
        return
    end

    if mode == "unreachable" or mode == "queued" then return end

    -- The bill the per-body work is actually signing up for.
    local gearBodies = (kinds.humanoid or 0)
    local wanted = math.ceil(poolTotal / TARGET_LIST)

    head("THE BILL — what a per-body drop table costs")
    print(string.format("  %d items to place.", poolTotal))
    print(string.format("  %d placed bodies, of which %d are humanoid.", placedTotal, gearBodies))
    print("")
    print("  docs/bestiary.md: bodied chaff carry priced, lootable gear; creature chaff carry natural")
    print("  weapons only. Demons and undead are UNSTATED there, and that gap moves the figure below.")
    print("")
    print(string.format("    over humanoids alone      %5.1f items per list  (%d bodies)",
        gearBodies > 0 and poolTotal / gearBodies or 0, gearBodies))
    print(string.format("    over every placed body    %5.1f items per list  (%d bodies)",
        placedTotal > 0 and poolTotal / placedTotal or 0, placedTotal))
    print("")
    print(string.format("  To land at %d per list you need %d gear-carrying bodies: %+d on today's %d.",
        TARGET_LIST, wanted, wanted - gearBodies, gearBodies))
    print("")
    print("  BAND ONLY is the long tail, not a backlog: the band is a permanent route and not every")
    print("  item is meant to come off a body (docs/drops.md). Read this number as how much of the")
    print("  catalogue no body is KNOWN FOR -- a quality figure, not a debt.")
    print("")
end

return M
