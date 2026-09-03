-- Shelf-gate rescale: rewrites every `unlockQuests` in data/items/**.lua from the retired four-value
-- wave enum ({ 0, 3, 6, 10 }) to a per-QUEST gate, so a house's shelf moves every time you finish one
-- of its quests instead of four times a campaign.
--
--   & "E:\LOVE\lovec.exe" . unlock-rescale          dry run -- per-house spread + a summary
--   & "E:\LOVE\lovec.exe" . unlock-rescale apply    rewrite the blueprints in place
--
-- THE RULE, per house:
--   * a house sponsors Q quests (12-14 today). Its shelf spreads across gates 0 .. Q-2, so the last
--     two quests of a line still open something rather than gating stock nobody can reach.
--   * the AUTHORED ORDER is preserved: items sort by their existing gate, then price, then id. That
--     ordering is the ranking the shelf was written with; only its granularity changes.
--   * the spread is even, so each quest lands roughly the same amount of new stock.
--   * a classless priced item gates at 0 -- the general store zeroes the gate anyway (Vendor.stock),
--     so any number there is dead data.
--   * the BASE shelf and the DISCIPLINE cut are spread separately. The base shelf takes 0 .. Q-2; the
--     discipline cut starts at 3, because no discipline unlocks before a line's third quest anyway
--     (see data/classes) -- so a discipline item down at gate 0 is a locked row sitting in front
--     of the stock a newcomer can actually buy, saying nothing its discipline lock did not.
--   * ONE EXCEPTION, pinned after the spread: every house must sell a WEAPON at gate 0. A class you
--     cannot buy a weapon from before running a single quest is a class you cannot start playing
--     (tests/class_spec.lua asserts exactly this), and an even spread has no reason to leave one there.
--
-- Items are ENUMERATED through the loaded model (Item.defs) and REWRITTEN by locating the literal
-- `unlockQuests = N` line in source. An item whose line cannot be located is reported and left alone,
-- which is safe: an unrescaled gate is a valid gate, just a coarse one.
--
-- Writes into the PROJECT source tree (not the LOVE save dir), exactly as tools/curve_migrate does.

local Item = require("models.item")
local Class = require("models.class") -- isEarned: deep stock vs the open rack, since the fold
local Vendor = require("models.vendor")
local Quest = require("models.quest")

local M = {}

-- The last two quests of a line open no new stock of their own -- they are the payoff, and gating
-- anything on "finish the whole line" puts it out of reach of the line that unlocks it.
local TAIL_MARGIN = 2

-- The earliest quest a discipline item's gate may name. No subclass unlocks before its line's third
-- quest ("a discipline handed over on a line's first or second quest is not earned advancement, it is
-- a welcome gift" -- data/classes/bombardier.lua), so nothing below this could ever be buyable.
local DISCIPLINE_FLOOR = 3

local function sourcePath(rel)
    return love.filesystem.getSource() .. "/" .. rel
end

local function readFile(rel)
    local f = io.open(sourcePath(rel), "rb")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return text
end

local function writeFile(rel, text)
    -- Never write a blueprint that would not parse -- the rewriter edits source text, so this is the
    -- one guard between a bad pattern and a broken data file.
    local ok, err = loadstring(text)
    assert(ok, "refusing to write invalid Lua to " .. rel .. ": " .. tostring(err))
    local f = assert(io.open(sourcePath(rel), "wb"))
    f:write(text)
    f:close()
end

-- class -> the vendor that sells it, and how many quests that house sponsors.
local function houseQuestCounts()
    local vendorOf, counts = {}, {}
    for id, def in pairs(Vendor.defs) do
        if def.class then vendorOf[def.class] = id end
    end
    for _, def in pairs(Quest.defs) do
        if def.sponsor then counts[def.sponsor] = (counts[def.sponsor] or 0) + 1 end
    end
    return vendorOf, counts
end

-- data/items/<type>/<id>.lua -- the layout Registry.load walks.
local function relPathFor(id, def)
    return "data/items/" .. tostring(def.type) .. "/" .. id .. ".lua"
end

-- Every priced item, bucketed by the class whose shelf gates it. A classless one lands under `false`.
local function bucketShelves()
    local shelves = {}
    for id, def in pairs(Item.defs) do
        if def.price then
            local key = def.class or false
            shelves[key] = shelves[key] or {}
            shelves[key][#shelves[key] + 1] = { id = id, def = def }
        end
    end
    for _, rows in pairs(shelves) do
        table.sort(rows, function(a, b)
            local ga, gb = a.def.unlockQuests or 0, b.def.unlockQuests or 0
            if ga ~= gb then return ga < gb end
            if a.def.price ~= b.def.price then return a.def.price < b.def.price end
            return a.id < b.id
        end)
    end
    return shelves
end

-- The new gate for row `i` of `n` on a band running minGate..maxGate: an even spread that opens the
-- first slice at minGate and reaches maxGate on the last.
local function gateFor(i, n, minGate, maxGate)
    local span = maxGate - minGate
    if n <= 1 or span <= 0 then return math.min(minGate, maxGate) end
    return minGate + math.floor((i - 1) * (span + 1) / n)
end

-- Rewrite the one `unlockQuests = N` assignment in `text`. Returns the new text, or nil when the
-- literal is not where the blueprint says it should be.
local function rewrite(text, value)
    local replaced, n = text:gsub("(unlockQuests%s*=%s*)%-?%d+", "%1" .. value, 1)
    if n ~= 1 then return nil end
    return replaced
end

function M.run(args)
    local apply = args and args[1] == "apply"
    local vendorOf, questCounts = houseQuestCounts()
    local shelves = bucketShelves()

    local classes = {}
    for key in pairs(shelves) do classes[#classes + 1] = key end
    table.sort(classes, function(a, b) return tostring(a) < tostring(b) end)

    local changed, missed, unchanged = 0, {}, 0

    for _, key in ipairs(classes) do
        local rows = shelves[key]
        local vendorId = key and vendorOf[key]
        local quests = vendorId and questCounts[vendorId] or 0
        local maxGate = key and math.max(0, quests - TAIL_MARGIN) or 0

        print(string.format("%-12s %3d items  ->  gates 0..%d  (%s sponsors %d quests)",
            key and tostring(key) or "classless", #rows, maxGate,
            vendorId or "no house", quests))

        -- Two bands, spread independently: the base shelf over the whole line, the discipline cut over
        -- what is left once the disciplines can actually be unlocked.
        local base, deep = {}, {}
        for _, row in ipairs(rows) do
            -- Deep stock is an EARNED class's since the fold (docs/class-fold.md); reading a
            -- `discipline` field here would put the whole catalogue in `base` and say nothing.
            if Class.isEarned(row.def.class) then deep[#deep + 1] = row else base[#base + 1] = row end
        end
        local wants = {}
        for i, row in ipairs(base) do wants[row.id] = gateFor(i, #base, 0, maxGate) end
        for i, row in ipairs(deep) do
            wants[row.id] = gateFor(i, #deep, math.min(DISCIPLINE_FLOOR, maxGate), maxGate)
        end

        -- Then pin an opening weapon onto gate 0 if the spread left none.
        if key then
            -- Deliberately only the BASE shelf: a discipline weapon at gate 0 is still locked behind
            -- its discipline, so pinning one there would satisfy the letter of the rule and arm nobody.
            local openingWeapon, cheapest
            for _, row in ipairs(rows) do
                if row.def.type == "weapon" and not Class.isEarned(row.def.class) then
                    if wants[row.id] <= 0 then openingWeapon = row end
                    if not cheapest or row.def.price < cheapest.def.price then cheapest = row end
                end
            end
            if not openingWeapon and cheapest then
                wants[cheapest.id] = 0
                print("    pinned " .. cheapest.id .. " to gate 0 (the house's opening weapon)")
            end
        end

        for _, row in ipairs(rows) do
            local want = wants[row.id]
            local have = row.def.unlockQuests
            if have == want then
                unchanged = unchanged + 1
            else
                local rel = relPathFor(row.id, row.def)
                local text = readFile(rel)
                local out = text and (have ~= nil and rewrite(text, want) or nil)
                if not out then
                    -- No literal to rewrite: either the file moved, or the item never authored a gate.
                    -- The latter is the real case (a priced item with no unlockQuests defaults to 0),
                    -- and 0 is what an ungated item should already be, so only report a real mismatch.
                    if want ~= 0 then missed[#missed + 1] = row.id .. " (wanted " .. want .. ")" end
                else
                    if apply then writeFile(rel, out) end
                    changed = changed + 1
                end
            end
        end
    end

    print("")
    print(string.format("%d gates rescaled, %d already correct, %d could not be located",
        changed, unchanged, #missed))
    for _, m in ipairs(missed) do print("  unlocatable: " .. m) end
    if not apply then print("\nDry run. Re-run with `apply` to write.") end
end

return M
