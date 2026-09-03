-- DROP TIERS: how deep you have to be for an unpriced item to fall out of a fight.
--
--     & "E:\LOVE\lovec.exe" . drop-tier [apply]
--
-- WHY THIS EXISTS. An item with a `class` and no `price` used to be quest-only by construction: no
-- vendor stocks it (Vendor.stock reads price) and the drop pool filters on price too
-- (Spoils.lootCandidates), so the ONLY way one could reach a player was a quest's `rewardItems`. The
-- houses stopped posting quests, thirty-five of them were deleted, and sixty-four unpriced items lost
-- their single source in one stroke -- dead data that loads, passes the schema, counts toward every
-- per-shelf promise in docs/classes.md, and can never appear in a save file.
--
-- The answer is the one the shelf already gives for everything else: what a thing is WORTH decides
-- where it sits. A priced item's grade sets its slot and its slot sets its price
-- (docs/shelf.md); an unpriced one has no slot to sit on, so its grade sets the DEPTH at which the rift
-- will give it up instead. Same instrument, same ranking, a different axis to spread it along.
--
-- WHAT IS DELIBERATELY LEFT ALONE:
--
--   SIGNATURES     an item tagged `signature` is a discipline exemplar's own relic -- Dov's Doorstone,
--                  the Demon Lord's Hollow Crown. Those ride the bearer (see the signature system) and
--                  are seated in that body's grid, not scattered through the floors. A signature in the
--                  drop pool would be a body's identity falling out of an unrelated fight.
--   BOUND          `bound = true` already means "nailed to one grid, never earned, bought, stolen or
--                  moved". Nothing about a tier applies.
--   PRICED         it has a shelf. That is its answer.
--
-- Report first. Nothing is written until you say `apply`.

local Item = require("models.item")
local Grade = require("models.grade")
local Discipline = require("models.discipline")

local M = {}

-- The deepest tier a find can carry, which is the class ladder's own height so that "how deep am I" and
-- "how far into a class am I" are quoted in one unit. Read off Discipline rather than typed, so
-- re-cutting the ladder moves this with it.
local function tiers()
    return Discipline.CLASS_LEVEL_CAP
end

local function hasTag(def, tag)
    for _, t in ipairs(def.tags or {}) do if t == tag then return true end end
    return false
end

-- Every item this pass is responsible for: classed, unpriced, unbound, and not somebody's signature.
function M.candidates()
    local out = {}
    for id, def in pairs(Item.defs) do
        if def.class and not def.price and not def.bound and not hasTag(def, "signature") then
            out[#out + 1] = id
        end
    end
    table.sort(out)
    return out
end

-- Rank them weakest-first and spread them evenly across 1..tiers().
--
-- EVENLY BY COUNT, exactly as the shelf spreads a house's stock, and for the same reason: the grades
-- are not evenly distributed and banding on grade THRESHOLDS would pile most of a small set onto one
-- tier and leave the rest of the rift with nothing to give up. What is being decided here is an order,
-- not a magnitude.
function M.plan()
    local ranked = {}
    for _, id in ipairs(M.candidates()) do
        local g = Grade.of(id)
        ranked[#ranked + 1] = { id = id, grade = (type(g) == "table" and g.value) or g or 0 }
    end
    -- Sorted by grade then id: `pairs` over the registry is unspecified, and a pass that dealt a
    -- different tier on two machines is a pass nothing can be written against.
    table.sort(ranked, function(a, b)
        if a.grade ~= b.grade then return a.grade < b.grade end
        return a.id < b.id
    end)

    local n, top = #ranked, tiers()
    for i, row in ipairs(ranked) do
        row.tier = n > 1 and (1 + math.floor((i - 1) * (top - 1) / (n - 1) + 0.5)) or 1
        row.was = Item.defs[row.id].dropTier
    end
    return ranked
end

local function rewrite(id, tier)
    local path
    for _, kind in ipairs({ "weapon", "armor", "utility", "consumable", "ability" }) do
        local p = "data/items/" .. kind .. "/" .. id .. ".lua"
        local f = io.open(p, "rb")
        if f then f:close(); path = p; break end
    end
    if not path then return false, "no file" end

    local f = io.open(path, "rb")
    local src = f:read("*a")
    f:close()

    local line = "    dropTier = " .. tier .. ","
    local out
    if src:match("\n%s*dropTier%s*=") then
        out = src:gsub("\n%s*dropTier%s*=[^\n]*", "\n" .. line, 1)
    else
        -- Seated just after `class`, which is the field it is the counterpart of: one says whose shelf
        -- this would be on, the other says how deep the rift keeps it instead.
        out = src:gsub("(\n%s*class%s*=[^\n]*\n)", "%1" .. line .. "\n", 1)
        if out == src then return false, "no class line to seat it after" end
    end

    local w = io.open(path, "wb")
    w:write(out)
    w:close()
    return true
end

function M.run(args)
    local apply = false
    for _, a in ipairs(args or {}) do if a == "apply" then apply = true end end

    local ranked = M.plan()
    print(string.format("\n######## DROP TIERS: %d unpriced, unbound, non-signature items over %d tiers ########\n",
        #ranked, tiers()))
    print(string.format("  %-42s %8s  %s", "item", "grade", "tier"))
    for _, row in ipairs(ranked) do
        local move = row.was and row.was ~= row.tier and string.format("  (was %d)", row.was) or ""
        print(string.format("  %-42s %8.1f  %4d%s", row.id, row.grade, row.tier, move))
    end

    if not apply then
        print("\nReport only -- nothing was written. Run `drop-tier apply` to write dropTier.")
        return
    end

    local wrote, failed = 0, {}
    for _, row in ipairs(ranked) do
        local ok, why = rewrite(row.id, row.tier)
        if ok then wrote = wrote + 1 else failed[#failed + 1] = row.id .. " (" .. tostring(why) .. ")" end
    end
    print(string.format("\n%d blueprint(s) written.", wrote))
    if #failed > 0 then
        print("could not write: " .. table.concat(failed, ", "))
    end
end

return M
