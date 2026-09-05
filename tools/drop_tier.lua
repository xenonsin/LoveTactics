-- DROP TIERS: how deep you have to be for an unpriced item to fall out of a fight.
--
--     & "E:\LOVE\lovec.exe" . drop-tier [apply]          -- spread the unpriced set over the tiers
--     & "E:\LOVE\lovec.exe" . drop-tier recut [apply]    -- decide WHICH items are unpriced first
--
-- TWO PASSES, RUN IN THAT ORDER. `recut` takes price off everything a house no longer sells; the bare
-- pass then spreads the enlarged unpriced set along depth. They are separate commands because the
-- first is a one-time re-premise of the shelf and the second is a thing that gets re-run every time
-- the grades move (see M.runRecut for the rule, and docs/shelf.md for the axis).
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
local Class = require("models.class")

local M = {}

-- The deepest tier a find can carry, which is the class ladder's own height so that "how deep am I" and
-- "how far into a class am I" are quoted in one unit. Read off Class rather than typed, so
-- re-cutting the ladder moves this with it.
local function tiers()
    return Class.CLASS_LEVEL_CAP
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

local function pathOf(id)
    for _, kind in ipairs({ "weapon", "armor", "utility", "consumable", "ability" }) do
        local p = "data/items/" .. kind .. "/" .. id .. ".lua"
        local f = io.open(p, "rb")
        if f then f:close(); return p end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- THE RECUT: which priced items stop being for sale at all
-- ---------------------------------------------------------------------------

-- WHAT A HOUSE STILL SELLS, and it is three things: an ABILITY, which is the houses' whole remaining
-- trade; a CONSUMABLE, because the stock decision made before a descent has to be makeable; and the
-- OPENER RUNG of a weapon ladder, the floor that re-arms a company holding nothing. Everything else a
-- house used to deal -- every weapon above the floor, every utility, every piece of armor -- is found
-- in the rift or not at all, and reaches a counter only once the company has carried one out.
--
-- THE FLOOR IS THE RUNG, NOT THE WORD "IRON". Nine of the ten iron weapons are priced at
-- unlockQuests 0 -- but two houses have no iron anything, and their rung 0 is a censer (priest) and a
-- lancet (alchemist). Cutting on the name would leave those two classes with no purchasable weapon in
-- the game, which is not a floor, it is a hole. Cutting on the rung covers all seven houses exactly
-- once and is DERIVED, so a later re-cut of the ladder moves it rather than stranding a hand-written
-- list behind (docs/shelf.md).
--
-- ONE ITEM IS NAMED RATHER THAN DERIVED, and it is worth the exception rather than worth a rule. The
-- rung-0 utilities were the old general store -- a torch, boots, a rod, sandals -- and all of them came
-- off the shelf with everything else. Only the torch goes back on: seeing in the dark is not a thing a
-- company should have to get lucky about, and a run that finds no light source is not playing the game
-- badly, it is playing a different and worse one. The other three are ordinary finds.
--
-- Named here rather than flagged on the blueprint, for the reason the balance waivers are: a per-file
-- opt-out is a field an author sets to make a pass stop complaining, and a line in this table is a line
-- somebody has to write a sentence next to.
local ALWAYS_STOCKED = {
    utility_torch = "seeing in the dark is not a thing to get lucky about",
}

local function staysPriced(def, id)
    if ALWAYS_STOCKED[id] then return true end
    if def.type == "ability" or def.type == "consumable" then return true end
    if def.type == "weapon" and (def.unlockQuests or 0) == 0 then return true end
    return false
end

-- Every priced item the recut takes off the shelf. Same three exemptions the tier pass makes -- bound,
-- signature, classless -- for the same reasons, so the two passes never disagree about what an item is.
function M.recutCandidates()
    local out = {}
    for id, def in pairs(Item.defs) do
        if def.class and def.price and not def.bound and not hasTag(def, "signature")
            and not staysPriced(def, id) then
            out[#out + 1] = id
        end
    end
    table.sort(out)
    return out
end

-- Take `price` off one blueprint -- and ONLY `price`.
--
-- `unlockQuests` STAYS, and getting that wrong once is worth the paragraph. It looks like shelf
-- furniture: docs/shelf.md says the rung means nothing on a ware with no price, so the first cut of
-- this pass took both. But the rung is not only a gate -- it IS the item's grade rank, and that is what
-- models/balance.lua reads as its POWER LEVEL (Balance.slotOf, Balance.magnitudeVerdict). Strip it and
-- two hundred blueprints answer slot 0, every one of them is measured against the opening rung's
-- budget, and a floor-eight hammer reports as wildly overpowered while a censer reports as feeble.
-- The number is authored, it is correct, and nothing else in the data carries it.
--
-- So the gate moves instead of the field: Vendor.stock simply does not apply a rung gate to an unpriced
-- ware, because its gate is having found one. Two questions, two fields, neither borrowed.
--
-- Anchored to line starts so a `price` inside a comment or a nested table is not eaten, and matching
-- [ \t] rather than %s so the pattern cannot run backwards over a blank line and close up the spacing
-- somebody wrote on purpose.
local function strip(id)
    local path = pathOf(id)
    if not path then return false, "no file" end

    local f = io.open(path, "rb")
    local src = f:read("*a")
    f:close()

    local out = src:gsub("\n[ \t]*price[ \t]*=[^\n]*", "", 1)
    if out == src then return false, "no price line" end

    local w = io.open(path, "wb")
    w:write(out)
    w:close()
    return true
end

function M.runRecut(apply)
    local ids = M.recutCandidates()

    local byClass, classes = {}, {}
    local byType = {}
    for _, id in ipairs(ids) do
        local def = Item.defs[id]
        local cls = def.class or "-"
        if not byClass[cls] then byClass[cls] = {}; classes[#classes + 1] = cls end
        table.insert(byClass[cls], id)
        byType[def.type or "-"] = (byType[def.type or "-"] or 0) + 1
    end
    table.sort(classes)

    print(string.format("\n######## RECUT: %d priced items come off the shelf ########\n", #ids))
    for _, cls in ipairs(classes) do
        print(string.format("  %s (%d)", cls, #byClass[cls]))
        for _, id in ipairs(byClass[cls]) do
            local def = Item.defs[id]
            print(string.format("      %-44s %-9s rung %d  %5dg", id, def.type or "-",
                def.unlockQuests or 0, def.price or 0))
        end
    end

    print("\n  by type:")
    local kinds = {}
    for k in pairs(byType) do kinds[#kinds + 1] = k end
    table.sort(kinds)
    for _, k in ipairs(kinds) do print(string.format("      %-10s %4d", k, byType[k])) end

    -- What is left standing on a counter, which is the half that decides whether a company that has
    -- found nothing can still arm itself. Reported every run: a recut that empties a house is the one
    -- failure this pass can cause and it must not need a second command to see.
    --
    -- ONLY A ROOT NEEDS A FLOOR. An earned class's stock lands on each of its parents' shelves too
    -- (Vendor.sells walks Class.parents), so a discipline with no opener weapon of its own is buying
    -- from the house it was cut from -- which is the fold working, not a hole. Warning on all forty of
    -- them buried the seven readings that mean anything.
    local kept = {}
    for id, def in pairs(Item.defs) do
        if def.class and def.price and staysPriced(def, id) then
            kept[def.class] = kept[def.class] or { ability = 0, consumable = 0, weapon = 0 }
            local slot = kept[def.class][def.type]
            if slot then kept[def.class][def.type] = slot + 1 end
        end
    end
    local shelves = {}
    for cls in pairs(kept) do shelves[#shelves + 1] = cls end
    table.sort(shelves)
    print("\n  what each house still sells:")
    for _, cls in ipairs(shelves) do
        local k = kept[cls]
        print(string.format("      %-12s %3d abilities  %3d consumables  %3d opener weapon(s)%s",
            cls, k.ability, k.consumable, k.weapon,
            (k.weapon == 0 and Class.isRoot(cls)) and "   <-- NO FLOOR" or ""))
    end

    if not apply then
        print("\nReport only -- nothing was written. Run `drop-tier recut apply` to strip price/unlockQuests,")
        print("then `drop-tier apply` to spread dropTier over the enlarged set.")
        return
    end

    local wrote, failed = 0, {}
    for _, id in ipairs(ids) do
        local ok, why = strip(id)
        if ok then wrote = wrote + 1 else failed[#failed + 1] = id .. " (" .. tostring(why) .. ")" end
    end
    print(string.format("\n%d blueprint(s) stripped.", wrote))
    if #failed > 0 then print("could not write: " .. table.concat(failed, ", ")) end
    print("Now run `drop-tier apply` to give them all a dropTier.")
end

local function rewrite(id, tier)
    local path = pathOf(id)
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
    local apply, recut = false, false
    for _, a in ipairs(args or {}) do
        if a == "apply" then apply = true elseif a == "recut" then recut = true end
    end
    if recut then return M.runRecut(apply) end

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
