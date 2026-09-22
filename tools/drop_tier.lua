-- DROP TIERS: how deep you have to be for an unpriced item to fall out of a fight.
--
--     & "E:\LOVE\lovec.exe" . drop-tier [apply]          -- spread the unpriced set over the tiers
--     & "E:\LOVE\lovec.exe" . drop-tier recut [apply]    -- decide WHICH items are unpriced first
--
-- TWO PASSES, RUN IN THAT ORDER. `recut` takes price off everything a house no longer prices; the bare
-- pass then spreads the enlarged unpriced set along depth. They are separate commands because the
-- first is a one-time re-premise of the shelf and the second is a thing that gets re-run every time
-- the grades move (see M.runRecut for the rule, and docs/shelf.md for the axis).
--
-- HALF THE RECUT WAS REVERSED, AND IT IS NOT THE HALF THIS FILE WRITES. The pricing decision stands:
-- above a house's opener nothing carries an authored `price`, and everything below writes a `unlockLevel`
-- instead. What went with it at the time was a DISCOVERY GATE -- no counter would deal a found ware
-- until the company had carried one out -- and that is gone (docs/shelf.md). A found ware is dealt at
-- its class rung now, and the rung is read off the very number this pass writes: `unlockLevel - 1`, the
-- same figure Vendor.foundPrice already quoted it at.
--
-- WHICH RAISES THE STAKES ON `apply` and is the one thing to know before re-running it. A tier used to
-- decide only how deep a thing fell. It now also decides WHAT A COUNTER CHARGES and WHEN IT WILL DEAL
-- ONE, so a re-spread moves three things at once. The report is not decoration here.
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
-- WHAT THIS PASS DOES NOT DECIDE, AND MUST NOT. A `unlockLevel` is the WORTH axis -- what a thing is
-- graded at, and (through Vendor.foundPrice) what a counter charges for one once you have carried it
-- out. Whether the player is ALLOWED it is a second question, answered at roll time by Spoils.depthOf
-- off the class's own gate, so a Warden find is refused floor one whatever it grades. Folding that
-- gate into the number written here would be the same mistake in a different file: it would re-price
-- twenty-six items by moving them eight rungs up a ladder that means "how good", to say something
-- about who has earned them. Two axes, one field each.
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
--   noSteal        a body part. `noSteal` is the blueprint saying this cannot be taken off the body
--                  wearing it -- a beast's fangs, a wyrm's breath -- and a thing a pickpocket cannot
--                  lift is not a thing that falls off the corpse either (docs/bestiary.md's split).
--                  ALL 92 OF THEM WERE BEING TIERED, and a tier is a licence: models/spoils.lua's
--                  pool admits any unpriced item that carries one, so every natural weapon in the
--                  game was in the drop table. The doc's claim that "the engine already enforces
--                  this economically" was true of the PRICE gate and died when this pass started
--                  handing out depths instead. Excluded here so a re-run stops minting the licence;
--                  the pool refuses them on `noSteal` directly, which is the gate that holds whatever
--                  this pass does.
--
-- Report first. Nothing is written until you say `apply`.

local Item = require("models.item")
local Grade = require("models.grade")
local Class = require("models.class")
local Curve = require("tools.shelf_curve") -- the ramp a rung deals on, shared with tools/grade_report

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
        if def.class and not def.price and not def.bound and not def.noSteal
            and not hasTag(def, "signature") then
            out[#out + 1] = id
        end
    end
    table.sort(out)
    return out
end

-- Rank them weakest-first, PER CLASS, and deal each house's finds up its own ladder on the shelf curve.
--
-- BY COUNT RATHER THAN BY GRADE THRESHOLD, which has not changed and is the older half of this: the
-- grades are not evenly distributed and banding on grade VALUE would pile most of a small set onto one
-- tier and leave the rest of the rift with nothing to give up. What is being decided is an order.
--
-- WHAT DID CHANGE IS THE AXIS THE ORDER IS CUT ON. This pass used to rank every find in the game
-- together and spread that ONE list over the depths, which reads as a claim -- that a tier is absolute
-- power, the same number for everybody -- and is not the claim the ladder makes anywhere else.
-- `unlockLevel` is a CLASS level (docs/shelf.md, "The slot"): the shelf gates a ware on its own class's
-- rung, and the rift and the shelf are one ladder read from two ends. Under a global cut the two ends
-- disagreed. A house with a thin catalogue had its finds bunched wherever its grades happened to land in
-- the global ranking, so the Bastion opened nine wares at knight 6 and one at knight 3, and fifteen of
-- the 112 rungs across the seven houses opened nothing at all.
--
-- Cut per class, a floor gives up the gear that floor was fought at, for every class, which is what the
-- doc always said it did. The cost is that absolute power at a depth now varies by class -- a thin
-- house's deepest find grades under a fat one's -- and that is the right cost: a class's ceiling is its
-- own, and the alternative was houses whose ladder had holes in it.
--
-- THE SPREAD IS THE SHELF CURVE (tools/shelf_curve.lua), the same ramp tools/grade_report deals the
-- priced half on. Two ramps over one ladder sum to a ramp; two spreads of different shapes sum to
-- neither, which is how the shipped histogram happened.
-- One band of one class, dealt up the ladder. Rows arrive ranked weakest-first; each comes out with a
-- `tier`.
--
-- THE AUTHORED PINS ARE HONOURED HERE, which they were not. `Grade.SLOT_PINS` is the one place a human
-- overrules the grader -- "a rock: the cheapest ware in the arena, and gated by nothing", "a rehomed
-- general good: un-gated since the Cafe closed its shelf" -- and tools/grade_report has always read it.
-- This pass never did, so one table governed a priced ware and was silently overwritten on an unpriced
-- one: the torch kept its pinned rung because it has a price, while boots of speed, the stormglass rod
-- and wellspring sandals were dealt 2, 10 and 7 against an authored `at = 0`. One contract, two writers,
-- one of them not reading it.
--
-- Pins are seated BEFORE the spread and counted against their tier's share, the shape grade_report uses:
-- laying a pin over a finished spread leaves a hole exactly where the pinned row used to sit.
local function dealBand(rows, globalTier)
    -- Tier 1 is the shallowest a find may sit at: rung 0 is the shelf's re-arm floor and no floor pays
    -- it (models/spoils.lua's rankBand reaches down to it and never centres on it). A pin is the one
    -- thing that may reach below it, because a pin is somebody saying so.
    local top = tiers()
    local spread, taken = {}, {}
    for _, row in ipairs(rows) do
        local pin = Grade.SLOT_PINS[row.id]
        if pin and pin.at then
            row.tier, row.pinned = pin.at, pin.why
            taken[row.tier] = (taken[row.tier] or 0) + 1
        else
            spread[#spread + 1] = row
        end
    end

    -- The share is of everything that lands IN the band, pins included, so a pinned row costs its own
    -- tier a place rather than arriving on top of a full one. A pin seated below the band -- an
    -- `at = 0` -- is not counted, or its share would be left unspent and the rows it displaced would
    -- fall through to the deepest tier.
    local inBand = #spread
    for t, count in pairs(taken) do
        if t >= 1 then inBand = inBand + count end
    end
    -- A BAND THINNER THAN THE LADDER KEEPS THE RIFT'S OWN ORDER, and this is the line the per-class cut
    -- may not cross.
    --
    -- A body's drop list is not one class's. The boar hands over plague knight, beastmaster and
    -- necromancer gear; the stag druid and vanguard gear -- and within one body's list, the TIER IS THE
    -- RARITY and nothing else (docs/drops.md; tests/boar_drops_spec, sow, stag, slime all read it that
    -- way). There is no per-entry weight to author: a floor picks a rank and then looks at who died, so
    -- the chase piece is the chase piece purely by sitting deepest.
    --
    -- Cut per class, a tier stops being comparable ACROSS classes: a strong piece in a thin house comes
    -- out shallower than a weak piece in a fat one, because each is a position on its own ladder rather
    -- than a measure of worth. Applied to everything, that reordered five chases into common drops.
    --
    -- SO THE CUT IS PER CLASS ONLY WHERE A CLASS CAN ACTUALLY FILL A LADDER. Measured, exactly the seven
    -- ROOT classes carry finds enough -- 20 to 57 against fifteen tiers -- and every one of the forty
    -- disciplines carries ten or fewer. A band that thin cannot shape a shelf whatever it is dealt: at
    -- one ware a rung at most, its curve is arbitrary. It CAN break a drop list, so it keeps the global
    -- grade order and the shelf loses nothing. The threshold is the curve's own (`n >= rungs`, the point
    -- at which every rung can be handed one), so the two cannot drift apart.
    local i = 1
    if globalTier and #spread < top then
        for _, row in ipairs(spread) do row.tier = globalTier[row.id] or top end
        i = #spread + 1
    else
        local shares = Curve.shares(inBand, top)
        for t = 1, top do
            local room = math.max(0, shares[t] - (taken[t] or 0))
            for _ = 1, room do
                if not spread[i] then break end
                spread[i].tier = t
                i = i + 1
            end
        end
    end
    -- Whatever the pins' displacement left over goes on the deepest tier, which is where the rarest
    -- finds belong -- the same place tools/grade_report puts its own remainder.
    for j = i, #spread do spread[j].tier = top end

    -- Range pins clamp afterwards: unlike an `at`, a min/max moves a row WITHIN the band rather than
    -- out of it, so it cannot leave a hole.
    for _, row in ipairs(rows) do
        local pin = Grade.SLOT_PINS[row.id]
        if pin and not pin.at then
            if pin.min and row.tier < pin.min then row.tier, row.pinned = pin.min, pin.why end
            if pin.max and row.tier > pin.max then row.tier, row.pinned = pin.max, pin.why end
        end
    end
end

-- THE RIFT'S OWN ORDER: every find in the game ranked weakest-first and dealt up the depths together,
-- which is what this pass did for everything before the per-class cut. Kept for the bands too thin to
-- carry a ladder of their own (dealBand), so a tier stays a statement about WORTH wherever it is still
-- being read as one.
local function globalOrder(rows)
    local all = {}
    for _, row in ipairs(rows) do all[#all + 1] = row end
    table.sort(all, function(a, b)
        if a.grade ~= b.grade then return a.grade < b.grade end
        return a.id < b.id
    end)

    -- EVENLY, NOT ON THE SHELF CURVE, and the difference matters. The curve is a PACING device: it
    -- thins a rung so a player is handed two or three choices rather than eight. This ranking is not
    -- pacing anything -- it exists so a tier still reads as a statement about worth -- and the curve's
    -- fat deep band destroys exactly that, because thirty-odd finds landing on tier 15 together are
    -- thirty finds with no order left between them. Measured, it tied the boar's chase with the horn it
    -- is supposed to be rarer than.
    local top, n = tiers(), #all
    local out = {}
    for i, row in ipairs(all) do
        out[row.id] = n > 1 and (1 + math.floor((i - 1) * (top - 1) / (n - 1) + 0.5)) or 1
    end
    return out
end

function M.plan()
    local byClass = {}
    for _, id in ipairs(M.candidates()) do
        local def = Item.defs[id]
        local g = Grade.of(id)
        local cls = def.class
        byClass[cls] = byClass[cls] or {}
        table.insert(byClass[cls], {
            id = id,
            class = cls,
            neverSold = (def.unstocked or def.dropOnly) and true or false,
            grade = (type(g) == "table" and g.value) or g or 0,
            was = def.unlockLevel,
        })
    end

    local classes, every = {}, {}
    for cls, list in pairs(byClass) do
        classes[#classes + 1] = cls
        for _, row in ipairs(list) do every[#every + 1] = row end
    end
    table.sort(classes)
    local global = globalOrder(every)

    local ranked = {}
    for _, cls in ipairs(classes) do
        local list = byClass[cls]
        -- Sorted by grade then id: `pairs` over the registry is unspecified, and a pass that dealt a
        -- different tier on two machines is a pass nothing can be written against.
        table.sort(list, function(a, b)
            if a.grade ~= b.grade then return a.grade < b.grade end
            return a.id < b.id
        end)

        -- TWO BANDS, DEALT SEPARATELY, and the one that is never for sale is the reason.
        --
        -- A ware no counter will ever DEAL stands on the rack named and greyed (docs/shelf.md). It is
        -- still a FIND, so it still needs a depth -- but it cannot pay for a rung of the shelf. Dealt in
        -- one band with the rest, a class level whose whole intake happened to be trophies opened
        -- nothing buyable at all, which is exactly the hole the curve's one-per-rung floor exists to
        -- close. Measured, the Hunter's Lodge had one: hunter 5 held the bristlehide and the ravener's
        -- hide and nothing else.
        --
        -- BOTH FLAGS, and reading only the first is a bug this already had. `unstocked` is a beast
        -- trophy, worth 0 to anybody in the city; `dropOnly` is the Mere's kit, which a fence will buy
        -- back but no counter will sell. They are different rules about SELLING BACK and the same rule
        -- about buying -- Vendor.lockReason answers "monster drop" to both -- and it is the buying half
        -- that decides whether a rung opened anything. Splitting on `unstocked` alone left the
        -- Undercroft's rung 1 holding one gillscale wrap, which is `dropOnly`, and opening nothing.
        --
        -- Split, the floor applies to each band on its own, so every rung gets a buyable find AND the
        -- trophies still span the rift instead of bunching where the sellable stock left room.
        local stocked, trophies = {}, {}
        for _, row in ipairs(list) do
            if row.neverSold then trophies[#trophies + 1] = row else stocked[#stocked + 1] = row end
        end
        dealBand(stocked, global)
        dealBand(trophies, global)

        for _, row in ipairs(list) do ranked[#ranked + 1] = row end
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
-- unlockLevel 0 -- but two houses have no iron anything, and their rung 0 is a censer (priest) and a
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
    if def.type == "weapon" and (def.unlockLevel or 0) == 0 then return true end
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
-- `unlockLevel` STAYS, and getting that wrong once is worth the paragraph. It looks like shelf
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
                def.unlockLevel or 0, def.price or 0))
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
        print("\nReport only -- nothing was written. Run `drop-tier recut apply` to strip price/unlockLevel,")
        print("then `drop-tier apply` to spread unlockLevel over the enlarged set.")
        return
    end

    local wrote, failed = 0, {}
    for _, id in ipairs(ids) do
        local ok, why = strip(id)
        if ok then wrote = wrote + 1 else failed[#failed + 1] = id .. " (" .. tostring(why) .. ")" end
    end
    print(string.format("\n%d blueprint(s) stripped.", wrote))
    if #failed > 0 then print("could not write: " .. table.concat(failed, ", ")) end
    print("Now run `drop-tier apply` to give them all an unlockLevel.")
end

local function rewrite(id, tier)
    local path = pathOf(id)
    if not path then return false, "no file" end

    local f = io.open(path, "rb")
    local src = f:read("*a")
    f:close()

    local line = "    unlockLevel = " .. tier .. ","
    local out
    if src:match("\n%s*unlockLevel%s*=") then
        out = src:gsub("\n%s*unlockLevel%s*=[^\n]*", "\n" .. line, 1)
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
    print(string.format("  %-14s %-42s %8s  %s", "class", "item", "grade", "tier"))
    local last
    for _, row in ipairs(ranked) do
        if row.class ~= last then last = row.class; print("") end
        local move = row.was and row.was ~= row.tier and string.format("  (was %d)", row.was) or ""
        print(string.format("  %-14s %-42s %8.1f  %4d%s", row.class, row.id, row.grade, row.tier, move))
    end

    -- The curve each house came out on, which is the whole point of the pass and cannot be read off a
    -- list five hundred rows long. This is the FOUND half only: what a player meets at a counter is
    -- this plus the priced spread (tools/grade_report), which rides the same ramp.
    print(string.format("\n  finds dealt per tier, by class (1..%d):", tiers()))
    local hist, classes = {}, {}
    for _, row in ipairs(ranked) do
        hist[row.class] = hist[row.class] or {}
        hist[row.class][row.tier] = (hist[row.class][row.tier] or 0) + 1
    end
    for cls in pairs(hist) do classes[#classes + 1] = cls end
    table.sort(classes)
    for _, cls in ipairs(classes) do
        local line = {}
        for t = 1, tiers() do line[#line + 1] = string.format("%3d", hist[cls][t] or 0) end
        print(string.format("      %-14s%s", cls, table.concat(line, "")))
    end

    if not apply then
        print("\nReport only -- nothing was written. Run `drop-tier apply` to write unlockLevel.")
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
