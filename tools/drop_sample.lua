-- DROP SAMPLE: what a floor actually pays, rolled rather than read.
--
--     & "E:\LOVE\lovec.exe" . drop-sample            -- every floor, the whole table
--     & "E:\LOVE\lovec.exe" . drop-sample 8          -- one floor, in detail
--     & "E:\LOVE\lovec.exe" . drop-sample n=20000    -- a wider sample
--
-- WHY THIS EXISTS, and why it is a THIRD instrument rather than a mode on either of the other two.
--
-- tools/drop_report.lua walks REACHABILITY -- can any body pay this item. tools/drop_assign.lua walks
-- ASSIGNMENT -- which body should. Neither of them rolls a single die, and every real defect in this
-- system so far has been invisible to both:
--
--   * the band weighted `1 + (tier - depth) / tier` under a comment promising the opposite, so the
--     further BELOW the floor an item sat the likelier it got. Reads fine. Correct-looking arithmetic.
--   * ~74% of drops came off the carried pool, which had no depth relationship at all -- so floor 8
--     averaged depth 1.98 and paid iron swords off level-16 bandits.
--   * every entry on a body's list drew at weight 1, so the piece it is known for was as common as
--     its worst.
--   * all 92 natural weapons sat in the drop pool, because `price` had stopped meaning "shoppable".
--
-- Each of those was found by writing a throwaway spec that sampled the loop and printed a table, and
-- each was then deleted with the spec. This is that spec, kept. A rewrite of the draw with no way to
-- measure the result is how nine tuning constants happened in the first place.
--
-- WHAT IT MEASURES, per floor, and each column answers a question somebody has actually asked:
--
--   PAID        drops per fight. Whether a floor pays at all.
--   RANK        the average `Spoils.depthOf` of what fell, against the floor's own tier. The headline:
--               these two numbers should track, and for a long time they did not.
--   NEAR        the share landing within a rung of the floor's tier -- the same figure in the form that
--               shows a distribution rather than a mean.
--   SOURCE      authored list / carried grid / price band. Which of the three routes is actually doing
--               the work, which is the number that explained why fixing the band changed nothing.
--   CLASS       the share whose class matches a body that was standing there. Once the floor picks the
--               rank and the body picks the identity, this is the column that says the second half is
--               working.
--   CONS        consumables. Supply rather than finds; it must not thin when gear rules change.
--
-- ROLLED AGAINST REAL BODIES. The roster for each floor is drawn from what that floor's circle can
-- actually field (tools/drop_report's own census), so this measures the game rather than a fixture --
-- a floor whose bodies carry nothing is a finding, not a broken harness.
--
-- Pure reporting; writes nothing.

local Character = require("models.character")
local Class = require("models.class")
local Descent = require("models.descent")
local Item = require("models.item")
local Spoils = require("models.spoils")

local M = {}

-- How many fights to roll per floor. Large, because the thing being measured is a distribution with a
-- 4%-ish tail in it -- at a thousand the standout's rate is noise, and the whole point of this pass is
-- to see a rate that small move.
local DEFAULT_N = 8000

-- The bodies a floor can field, off the same census `. drop-report` grades against, filtered to the
-- circle that floor belongs to. Falls back to everything placed when a circle seats nobody.
local function bodiesFor(floor)
    local placed = require("tools.drop_report").placement()
    local order = Descent.sinOrder(1, false)
    -- The stack is seven circles and then the Crown (Descent.FLOORS), so the last floor owns no sin
    -- and must not borrow the seventh's -- it would report Pride twice and quietly average two
    -- different floors' rosters under one name.
    local sin = floor <= #order and order[floor] or nil
    local gated, any = {}, {}
    for charId, row in pairs(placed) do
        local def = Character.defs[charId]
        if def and not def.boss then
            any[#any + 1] = charId
            if sin and sin.biome and row.biomes[sin.biome] then gated[#gated + 1] = charId end
        end
    end
    table.sort(gated); table.sort(any)
    local pool = #gated > 0 and gated or any
    return pool, sin
end

local function roster(pool, seedIdx)
    local units = {}
    for i = 1, 3 do
        local id = pool[((seedIdx + i) % #pool) + 1]
        units[i] = { char = Character.instantiate(id) }
    end
    return units
end

-- Everything one roster is holding or is known for -- used to attribute a drop to a route.
-- The three rungs the draw actually has, so the report can name which one answered. It used to have
-- only "was it in a grid or a list, else call it the band" -- which under the two-step draw lumps a
-- body's own HOUSE stock in with a generic draw and reported 90% band on a floor where the house rung
-- was doing most of the work.
local function sourcesOf(units)
    local own, classes = {}, {}
    for _, u in ipairs(units) do
        local def = Character.defs[u.char.id]
        if def then
            local lootClass = Spoils.lootClassOf(def, u)
            if lootClass then classes[lootClass] = true end
            for _, id in ipairs(def.drops or {}) do own[id] = true end
        end
        for _, item in ipairs(Character.eachItem(u.char)) do
            local d = Item.defs[item.id]
            if d and d.price and d.price > 0 then own[item.id] = true end
        end
    end
    return own, classes
end

local function sampleFloor(floor, n)
    local pool, sin = bodiesFor(floor)
    if #pool == 0 then return nil end
    -- Descent.floorLevel's own arithmetic: 1 + (floor - 1) * LEVEL_PER_FLOOR, so floor one is level
    -- ONE. Multiplying instead reports every floor a rung deep and floor 8 two rungs past anything the
    -- game produces -- the same unit slip that let the Touchstone fee overshoot by half.
    local level = 1 + (floor - 1) * Descent.LEVEL_PER_FLOOR
    -- THE BAND IS ASKED OF THE MODEL, never recomputed here. The first cut of this report derived its
    -- own `min(CLASS_LEVEL_CAP, floor * LEVEL_PER_FLOOR)` and kept using it after the draw stopped --
    -- so every "vs tier" figure was measured against a definition the game no longer held, and the
    -- middle floors read as a collapse that was not happening. An instrument that computes the thing it
    -- is checking is checking itself.
    local lo, hi, tier = Spoils.rankBand({ floorLevel = level })

    local drops, rankSum, near, cons = 0, 0, 0, 0
    local fromAuthored, fromCarried, fromBand, classMatch = 0, 0, 0, 0

    for i = 1, n do
        local units = roster(pool, i)
        local own, classes = sourcesOf(units)
        for _, id in ipairs(Spoils.roll({
            enemyUnits = units, day = 20, floorLevel = level, kind = "combat",
        }).loot) do
            local def = Item.defs[id]
            if def then
                drops = drops + 1
                local d = Spoils.depthOf(def)
                rankSum = rankSum + d
                if d >= tier - 1 then near = near + 1 end
                if def.type == "consumable" then cons = cons + 1 end
                if classes[def.class] then classMatch = classMatch + 1 end
                -- Named for the rung that answered: the body's OWN (its list or its grid), its HOUSE
                -- (its loot class's stock at that rank), or ANY (nothing standing here had stock).
                if own[id] then fromAuthored = fromAuthored + 1
                elseif def.class and classes[def.class] then fromCarried = fromCarried + 1
                else fromBand = fromBand + 1 end
            end
        end
    end

    local function pct(k) return drops > 0 and (k / drops * 100) or 0 end
    return {
        floor = floor, sin = sin and sin.id or "(crown)", tier = tier, bodies = #pool,
        paid = drops / n,
        rank = drops > 0 and rankSum / drops or 0,
        near = pct(near), cons = pct(cons), classMatch = pct(classMatch),
        authored = pct(fromAuthored), carried = pct(fromCarried), band = pct(fromBand),
        drops = drops,
    }
end

function M.run(args)
    args = args or {}
    local only, n = nil, DEFAULT_N
    for _, a in ipairs(args) do
        local num = tostring(a):match("^n=(%d+)$")
        if num then n = tonumber(num)
        elseif tonumber(a) then only = tonumber(a) end
    end

    print(string.rep("=", 78))
    print("DROP SAMPLE -- what a floor actually pays, rolled")
    print(string.rep("=", 78))
    print(string.format("  %d fights a floor, three bodies apiece, drawn from the circle's own roster.",
        n))
    print("")
    print("  fl  circle      rank  paid  got   (vs)   near   class     own   house    any   cons")
    print("  " .. string.rep("-", 74))

    local rows = {}
    for floor = 1, Descent.FLOORS do
        if not only or floor == only then
            local r = sampleFloor(floor, n)
            if r then
                rows[#rows + 1] = r
                print(string.format(
                    "  %2d  %-10s  %3d  %5.2f %5.2f  (%2d)  %5.1f%% %5.1f%%   %5.1f%% %5.1f%% %5.1f%% %5.1f%%",
                    r.floor, r.sin, r.tier, r.paid, r.rank, r.tier, r.near, r.classMatch,
                    r.authored, r.carried, r.band, r.cons))
            end
        end
    end

    if #rows == 0 then
        print("  nothing sampled")
        return
    end

    -- THE HEADLINE, said in one line rather than left to be read off a table: does what a floor pays
    -- track how deep that floor is? A ratio rather than a difference, so it means the same at both
    -- ends of the stack.
    print("")
    print(string.rep("=", 78))
    print("READINGS")
    print(string.rep("=", 78))
    local first, last = rows[1], rows[#rows]
    print(string.format("  rank vs depth : floor %d pays rank %.2f against tier %d (%.0f%% of it)",
        first.floor, first.rank, first.tier, first.rank / math.max(1, first.tier) * 100))
    print(string.format("                  floor %d pays rank %.2f against tier %d (%.0f%% of it)",
        last.floor, last.rank, last.tier, last.rank / math.max(1, last.tier) * 100))
    print("")
    print("  A floor whose rank sits far under its tier is paying gear that belongs to a shallower")
    print("  floor. The two lines above are the before/after any change to the draw is judged on.")
    print("")

    -- THE TIER SATURATES, and this is the first thing this instrument found that reading could not.
    --
    -- `tier` is min(CLASS_LEVEL_CAP, floor * LEVEL_PER_FLOOR) -- 8 and 2 -- so it pins at the cap from
    -- floor FOUR, and the back half of the stack is one undifferentiated band. Every floor from 4 down
    -- is being asked the same question about depth and can only give the same answer.
    --
    -- It is reported rather than fixed here because the fix is a design decision with two honest
    -- answers -- stretch the item ladder past 8, or accept that the deep half of the run differentiates
    -- on danger rather than on loot rank -- and a report that silently picked one would be making it.
    local saturated = {}
    for _, r in ipairs(rows) do
        if r.tier >= Class.CLASS_LEVEL_CAP then saturated[#saturated + 1] = r.floor end
    end
    if #saturated > 1 then
        print(string.format("  TIER SATURATION: floors %d-%d all sit at tier %d (the ladder's cap).",
            saturated[1], saturated[#saturated], Class.CLASS_LEVEL_CAP))
        print(string.format("                  %d of %d floors share one rank band, so depth stops",
            #saturated, #rows))
        print("                  separating what they pay. `tier` is min(CLASS_LEVEL_CAP,")
        print("                  floor x LEVEL_PER_FLOOR) and pins from floor "
            .. saturated[1] .. " onward.")
        print("")
    end

    local a, c, b = 0, 0, 0
    for _, r in ipairs(rows) do a, c, b = a + r.authored, c + r.carried, b + r.band end
    print(string.format("  route mix     : %.0f%% own  %.0f%% house  %.0f%% any  (mean over %d floors)",
        a / #rows, c / #rows, b / #rows, #rows))
    print("                  Whichever of these is largest is the one a tuning change will move.")
    print("                  Fixing the BAND while it was a quarter of drops moved 7.6% to 9.6%.")
    print("")
    local cm = 0
    for _, r in ipairs(rows) do cm = cm + r.classMatch end
    print(string.format("  class match   : %.0f%% of drops share a class with a body that was standing there.",
        cm / #rows))
    print("                  Once the floor picks the rank and the body picks the identity, this is")
    print("                  the column that says the second half is working. Rung 3 of that draw --")
    print("                  a generic item because the body's class had nothing at that rank -- is")
    print("                  expected and not a fault: the class ladders are deliberately not filled.")
end

return M
