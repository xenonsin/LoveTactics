-- LADDER FOLD: two numbers on one ladder become one.
--
--     & "E:\LOVE\lovec.exe" . ladder-fold          dry run -- the spread, the movers, the outliers
--     & "E:\LOVE\lovec.exe" . ladder-fold apply    rewrite the blueprints in place
--
-- WHAT WAS WRONG. An item carried up to two positions on what had become the same ladder:
--
--   unlockQuests   THE GRADE RANK. Named for a quest board that is retired, spread by tools/grade_report
--                  over 0..8, and read by models/balance.lua as the item's power level.
--   dropTier       THE DEPTH the rift gives it up at, spread by tools/drop_tier over 1..8, and read by
--                  models/vendor.lua as the shelf gate -- off by one, because tiers counted from 1 and
--                  class levels from 0.
--
-- 231 blueprints carried BOTH, and nothing on the blueprint said which one governed. The two readers
-- disagreed by construction: Vendor.lockReason took `unlockQuests` on anything priced and `dropTier - 1`
-- on anything not, while Spoils.rank took `dropTier or unlockQuests + 1`. A field whose meaning depends
-- on which of two other fields is present is a field that will be authored wrongly, and was.
--
-- MEASURED BEFORE FOLDING, because "these two say the same thing" is a claim and not an observation.
-- Across the 230 unpriced blueprints carrying both, `depth - rank` ran:
--
--     -3:  5    -2: 56    -1: 90    0: 38    +1: 18    +2: 14    +3:  7    +4:  2
--
-- 184 of 230 within a single rung, and exactly two outliers (utility_duelists_reflex and
-- utility_stormglass_rod, both rank 0 at depth 4). So collapsing the axes costs at most a rung of power
-- target on four fifths of the set -- which is inside the band an item already shares with everything
-- else on its rung -- and leaves two blueprints to look at by hand. That is what made the fold cheap;
-- had the histogram been flat it would have been a rebalance.
--
-- WHICH READING SURVIVES: THE DEPTH. Both were candidates and the depth won on two counts. It is what
-- the player experiences -- which floor pays the thing -- and it is what the per-body drop lists assert
-- orderings against (tests/boar_drops_spec, sow, stag, slime all read "depth IS the rarity"). Taking the
-- rank instead would have preserved a power target nobody can see at the cost of reordering every
-- chase piece in the game, which is the exact failure a pure-grade re-spread produced when it was tried.
--
-- AND THE LADDER WIDENS IN THE SAME PASS, because doing it in two would have moved the data twice.
-- Class.CLASS_LEVEL_CAP went from 8 to 15 (one rung per floor), so the old nine-band ladder is stretched
-- over sixteen. A PROPORTIONAL stretch alone would leave half the new rungs empty -- band 1 to rung 2,
-- band 2 to rung 4, and nothing at 1, 3, 5 -- so each old band is SPLIT IN TWO by grade: the weaker half
-- of a band takes the lower of its two new rungs, the stronger half the upper.
--
-- THE SPLIT CANNOT REORDER ANYTHING, which is the property that makes it safe where a global re-rank was
-- not. Every rung in S_b is below every rung in S_(b+1), so two items that were ordered by band stay
-- ordered; only items that SHARED a band can now separate, and a shared band is precisely the case where
-- the old ladder had no opinion. That is why this exists instead of `. drop-tier apply`, which re-ranks
-- globally by grade and, run against this data, moved the sow's pelt from tier 8 to tier 2 -- it grades
-- 1.6 and is authored deep because it is the chase. A grade spread cannot see that; a stretch does not
-- need to.
--
-- Writes into the PROJECT source tree, in binary, preserving each file's own line endings -- this tree
-- is CRLF under core.autocrlf and a rewriter that emits "\n" leaves a file with mixed endings.

local Item = require("models.item")
local Grade = require("models.grade")
local Class = require("models.class")

local M = {}

-- The ladder the authored data is ON, as distinct from Class.CLASS_LEVEL_CAP, which is the ladder it is
-- going TO. A migration is the one kind of code that legitimately knows both, and it has to say the old
-- one out loud: read from the live constant and the pass becomes a no-op the second time the cap moves.
M.OLD_CAP = 8

-- Every new rung old band `b` may land on. Derived rather than tabulated so re-cutting either cap
-- restretches this instead of silently dropping the top band on the floor.
--
-- THE TWO ENDS ARE PINNED AND THE MIDDLE IS SPREAD, which is not tidiness. Nine bands do not divide
-- sixteen rungs, so two bands must take one rung apiece -- and a flat `b * new / old` chose which two by
-- rounding, landing on band 4 and piling 84 items on rung 8 in the middle of the ladder. The ends are
-- the right two to pin because they are the two that MEAN something indivisible: band 0 is the opening
-- rack, which is defined by being buyable before anything is climbed and cannot be half-open, and the
-- top band is the deepest stock in the game. The seven interior bands then divide the fourteen rungs
-- between them exactly.
function M.rungsFor(b)
    local old, new = M.OLD_CAP, Class.CLASS_LEVEL_CAP
    if b <= 0 then return 0, 0 end
    if b >= old then return new, new end
    local span = math.max(1, old - 1)
    local lo = 1 + math.floor((b - 1) * (new - 1) / span + 0.5)
    local hi = math.floor(b * (new - 1) / span + 0.5)
    if hi < lo then hi = lo end
    return lo, math.min(hi, new - 1)
end

-- THE ONE READING OF AN ITEM'S OLD POSITION, and the whole point of the fold is that there is one.
-- A priced ware named its gate outright; an unpriced one named a depth that counted from 1 where the
-- class ladder counts from 0. Returns nil for a blueprint on neither axis -- bound gear, a signature,
-- creature kit -- which must stay off the ladder rather than being dealt a rung of 0.
function M.oldBand(def)
    if not def then return nil end
    if def.price then return def.unlockQuests or 0 end
    if def.dropTier then return math.max(0, def.dropTier - 1) end
    return nil
end

function M.plan()
    -- Group by old band, then rank within it. `pairs` over the registry promises no order and a pass
    -- that dealt a different rung on two machines is a pass nothing can be written against, so the
    -- sort settles ties on the id.
    local bands = {}
    for id, def in pairs(Item.defs) do
        local b = M.oldBand(def)
        if b then
            local g = Grade.of(id)
            bands[b] = bands[b] or {}
            table.insert(bands[b], {
                id = id,
                def = def,
                grade = (type(g) == "table" and g.value) or g or 0,
                band = b,
            })
        end
    end

    local rows = {}
    for b, list in pairs(bands) do
        table.sort(list, function(x, y)
            if x.grade ~= y.grade then return x.grade < y.grade end
            return x.id < y.id
        end)
        local lo, hi = M.rungsFor(b)
        local slots = hi - lo + 1
        for i, row in ipairs(list) do
            -- Evenly by count across the band's own rungs, weakest first. Not by grade THRESHOLD: the
            -- grades inside a band are not evenly distributed and banding on the value would pile most
            -- of a band onto one rung, which is the whole failure the stretch exists to avoid.
            local k = math.min(slots - 1, math.floor((i - 1) * slots / #list))
            row.want = lo + k
            row.from = b
            rows[#rows + 1] = row
        end
    end
    table.sort(rows, function(x, y)
        if x.want ~= y.want then return x.want < y.want end
        return x.id < y.id
    end)
    return rows
end

local function pathOf(id)
    local def = Item.defs[id]
    local dir = def and def.type or "utility"
    local rel = "data/items/" .. dir .. "/" .. id .. ".lua"
    local full = love.filesystem.getSource() .. "/" .. rel
    local f = io.open(full, "rb")
    if f then f:close() return full end
    return nil
end

-- Rewrite one blueprint: `unlockLevel` replaces whichever of the two old fields it carried, and any
-- other one is deleted. Byte-exact apart from the lines it touches -- the newline is taken FROM the
-- line being replaced, so a CRLF file stays CRLF (tools/drop_tier's own rewriter does not do this and
-- leaves mixed endings behind it).
local function rewrite(id, level)
    local path = pathOf(id)
    if not path then return false, "no file" end
    local f = io.open(path, "rb")
    local src = f:read("*a")
    f:close()

    local eol = src:match("\r\n") and "\r\n" or "\n"
    local indent = src:match("\n([ \t]*)[%a_]+%s*=") or "    "
    local line = indent .. "unlockLevel = " .. level .. ","

    local out, hits = src, 0
    -- The first of the two old fields becomes the new one, in place, so the field keeps its seat in the
    -- blueprint and the diff reads as a rename rather than as a move.
    for _, field in ipairs({ "unlockQuests", "dropTier" }) do
        local pat = "\r?\n[ \t]*" .. field .. "%s*=[^\r\n]*"
        if out:find(pat) then
            if hits == 0 then
                out = out:gsub(pat, eol .. line, 1)
            else
                out = out:gsub(pat, "", 1)   -- the second one is the duplicate the fold deletes
            end
            hits = hits + 1
        end
    end
    if hits == 0 then return false, "neither field found" end

    local w = io.open(path, "wb")
    w:write(out)
    w:close()
    return true
end

function M.run(args)
    local apply = false
    for _, a in ipairs(args or {}) do if a == "apply" then apply = true end end

    local rows = M.plan()
    print("")
    print(string.format("######## LADDER FOLD: %d items, %d bands -> %d rungs ########",
        #rows, M.OLD_CAP + 1, Class.CLASS_LEVEL_CAP + 1))
    print("")
    print("  old band -> new rungs, and how the stretch fills them:")
    local perBand, perRung, dupes = {}, {}, 0
    for _, r in ipairs(rows) do
        perBand[r.from] = (perBand[r.from] or 0) + 1
        perRung[r.want] = (perRung[r.want] or 0) + 1
        if r.def.unlockQuests and r.def.dropTier then dupes = dupes + 1 end
    end
    for b = 0, M.OLD_CAP do
        local lo, hi = M.rungsFor(b)
        local counts = {}
        for n = lo, hi do counts[#counts + 1] = string.format("%d:%d", n, perRung[n] or 0) end
        print(string.format("    band %d (%3d items) -> rungs %-5s   %s",
            b, perBand[b] or 0, lo == hi and tostring(lo) or (lo .. "-" .. hi),
            table.concat(counts, "  ")))
    end

    print("")
    print("  the new ladder, item count per rung:")
    for n = 0, Class.CLASS_LEVEL_CAP do
        print(string.format("    rung %2d : %4d", n, perRung[n] or 0))
    end
    print("")
    print(string.format("  %d blueprints carry both old fields and will come out with one.", dupes))

    if not apply then
        print("")
        print("Report only -- nothing was written. Run `ladder-fold apply` to rewrite the blueprints.")
        return
    end

    local wrote, failed = 0, {}
    for _, r in ipairs(rows) do
        local ok, why = rewrite(r.id, r.want)
        if ok then wrote = wrote + 1 else failed[#failed + 1] = r.id .. " (" .. tostring(why) .. ")" end
    end
    print("")
    print(string.format("%d blueprint(s) written.", wrote))
    if #failed > 0 then print("could not write: " .. table.concat(failed, ", ")) end
end

return M
