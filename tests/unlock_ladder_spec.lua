-- Tests for THE ONE LADDER: `unlockLevel` on an item IS a class level (Class.CLASS_LEVEL_CAP), and the
-- authored catalogue has to span it.
--
-- WHY THIS EXISTS. The gate an item opens on is a CLASS LEVEL -- Quest.shelfRung reads the roster's
-- best holder and Vendor.lockReason compares it straight to `unlockLevel` -- so the two ladders are the
-- same ladder and the data has to be spread along the whole of it. Nothing enforced that. The cap moved
-- from 8 to 15 and every number in data/items stayed where it was, which left the top seven rungs of
-- every shelf empty and the whole catalogue buyable by the middle of a descent; the fold that fixed it
-- (tools/ladder_fold) is a ONE-SHOT migration off the old eight-rung ladder and cannot be re-run.
--
-- So the next re-cut has no tool waiting for it, and this is what will say so. Every case here is
-- derived from Class.CLASS_LEVEL_CAP rather than from a number typed at the time.

local Item = require("models.item")
local Class = require("models.class")
local Vendor = require("models.vendor")

-- Every blueprint the ladder ranks. An item with no `unlockLevel` is off it on purpose -- bound gear, a
-- signature relic, creature kit -- and must NOT be dealt a rung of 0 just to have one.
local function ranked()
    local out = {}
    for id, def in pairs(Item.defs) do
        if def.unlockLevel then out[id] = def end
    end
    return out
end

local function histogram()
    local hist = {}
    for _, def in pairs(ranked()) do
        hist[def.unlockLevel] = (hist[def.unlockLevel] or 0) + 1
    end
    return hist
end

return {
    {
        name = "nothing is gated past the top of the ladder that opens it",
        fn = function()
            local bad = {}
            for id, def in pairs(ranked()) do
                if def.unlockLevel > Class.CLASS_LEVEL_CAP or def.unlockLevel < 0 then
                    bad[#bad + 1] = string.format("%s at %d", id, def.unlockLevel)
                end
            end
            table.sort(bad)
            assert(#bad == 0, string.format(
                "the class ladder runs 0..%d and these sit off it, so nothing can ever open them:\n  %s",
                Class.CLASS_LEVEL_CAP, table.concat(bad, "\n  ")))
        end,
    },

    {
        name = "every rung of the class ladder opens something",
        fn = function()
            local hist = histogram()
            local empty = {}
            for rung = 0, Class.CLASS_LEVEL_CAP do
                if (hist[rung] or 0) == 0 then empty[#empty + 1] = tostring(rung) end
            end
            assert(#empty == 0, string.format(
                "rung(s) %s open no stock at all -- a class level that buys nothing is a level-up the "
                .. "player is told about and cannot spend. Re-spread the catalogue across 0..%d "
                .. "(tools/ladder_fold's stretch is the pattern).",
                table.concat(empty, ", "), Class.CLASS_LEVEL_CAP))
        end,
    },

    {
        name = "and no rung is carrying a share of the catalogue the others are not",
        fn = function()
            -- A SPREAD, NOT JUST A SPAN. The failure this guards is the one a naive proportional
            -- re-scale produces: every old band maps onto one new rung, the rungs between them come
            -- out empty, and the ones that are filled hold double. The case above catches the empty
            -- half; this catches the bunching, which is the same defect read from the other side.
            local hist = histogram()
            local total, rungs = 0, Class.CLASS_LEVEL_CAP + 1
            for _, n in pairs(hist) do total = total + n end
            local mean = total / rungs

            local worst, worstRung = 0, nil
            for rung = 0, Class.CLASS_LEVEL_CAP do
                local n = hist[rung] or 0
                if n > worst then worst, worstRung = n, rung end
            end
            -- Rung 0 USED to be allowed to be the fat one, on the argument that it is the opening
            -- rack and the one rung no floor pays. It is the THIN one now, and by construction: it is
            -- the re-arm floor, holding a house's opener and the handful of wares an author has pinned
            -- as gated by nothing (tools/grade_report's SHELF_FLOOR). The exemption is gone with the
            -- band it excused -- rung 0 held 56 wares against a mean of 41 and now holds 20.
            assert(worst <= mean * 2, string.format(
                "rung %d holds %d of %d wares against a mean of %.1f -- the ladder is bunched, so "
                .. "some class levels open a flood and others a trickle",
                worstRung, worst, total, mean))
        end,
    },

    {
        name = "a shelf actually opens across the whole ladder, not just in the data",
        fn = function()
            -- THROUGH THE REAL GATE, because the two cases above read the blueprints and a blueprint
            -- is not a shelf: Vendor.lockReason is what the shop asks, and a rung that opens stock no
            -- house sells is a rung that opens nothing. Asked of the seven counters together, which is
            -- how a player meets the city.
            local HOUSES = { "alchemist", "arcanum", "bastion", "cathedral",
                             "colosseum", "hunters_lodge", "undercroft" }
            local unlocked, levels = {}, {}
            for id in pairs(Class.defs) do
                if Class.isRoot(id) then unlocked[id] = true end
            end

            local open = {}
            for rung = 0, Class.CLASS_LEVEL_CAP do
                for id in pairs(unlocked) do levels[id] = rung end
                local n = 0
                for _, vendor in ipairs(HOUSES) do
                    for _, row in ipairs(Vendor.stock(vendor, rung, nil, unlocked, levels)) do
                        if not row.locked then n = n + 1 end
                    end
                end
                open[rung] = n
            end

            assert(open[0] > 0, "the opening rack is empty -- a company can buy nothing on arrival")
            for rung = 1, Class.CLASS_LEVEL_CAP do
                assert(open[rung] >= open[rung - 1], string.format(
                    "rung %d opens fewer rows (%d) than rung %d (%d) -- a shelf may never shut",
                    rung, open[rung], rung - 1, open[rung - 1]))
            end
            assert(open[Class.CLASS_LEVEL_CAP] > open[0], string.format(
                "the whole ladder opens nothing beyond the opening rack: %d rows at rung 0 and %d at "
                .. "the cap", open[0], open[Class.CLASS_LEVEL_CAP]))

            -- THE TOP RUNG MUST PAY FOR ITSELF. Mastering a class is fifteen floors of committed play
            -- (Class.CLASS_LEVEL_STEP); arriving to find the shelf unchanged is the reward not landing.
            assert(open[Class.CLASS_LEVEL_CAP] > open[Class.CLASS_LEVEL_CAP - 1], string.format(
                "the last rung of the class ladder opens nothing: %d rows at rung %d and %d at %d",
                open[Class.CLASS_LEVEL_CAP - 1], Class.CLASS_LEVEL_CAP - 1,
                open[Class.CLASS_LEVEL_CAP], Class.CLASS_LEVEL_CAP))
        end,
    },

    {
        name = "every rung of every house opens something a player can BUY",
        fn = function()
            -- THE SAME PROMISE AS "every rung opens something", ASKED PER HOUSE AND THROUGH THE TILL.
            -- The case above reads the blueprints across the whole catalogue, and a catalogue is not a
            -- shelf: a player climbs ONE class at a time and meets one counter, so a rung that opens
            -- something at the Arcanum has opened nothing for a knight. Measured when this was written,
            -- fifteen of the 112 house-rungs in the city opened nothing at all, and every one of them
            -- was invisible to the global case because some other house always filled the rung.
            --
            -- BUYABLE, not merely present. An `unstocked` ware -- a body's own trophy -- stands on the
            -- rack named and greyed and is never for sale (docs/shelf.md), so a rung whose whole intake
            -- is trophies is a class level that changes nothing the player can act on. The Lodge had
            -- exactly one: hunter 5 held the bristlehide and the ravener's hide and nothing else.
            local HOUSES = { "alchemist", "arcanum", "bastion", "cathedral",
                             "colosseum", "hunters_lodge", "undercroft" }
            local unlocked, levels = {}, {}
            for id in pairs(Class.defs) do
                if Class.isRoot(id) then unlocked[id] = true end
            end

            local dead = {}
            for _, vendor in ipairs(HOUSES) do
                local prev = 0
                for rung = 0, Class.CLASS_LEVEL_CAP do
                    for id in pairs(unlocked) do levels[id] = rung end
                    local open = 0
                    for _, row in ipairs(Vendor.stock(vendor, rung, nil, unlocked, levels)) do
                        if not row.locked then open = open + 1 end
                    end
                    if open - prev <= 0 then
                        dead[#dead + 1] = string.format("%s at rung %d", vendor, rung)
                    end
                    prev = open
                end
            end
            assert(#dead == 0, string.format(
                "%d house-rung(s) open nothing buyable -- a class level the player is told about and "
                .. "cannot spend:\n  %s\nThe curve that is supposed to prevent this is "
                .. "tools/shelf_curve.lua; re-run `. grade-report apply` then `. drop-tier apply`.",
                #dead, table.concat(dead, "\n  ")))
        end,
    },

    {
        name = "the opening rung is the re-arm floor and not a rack",
        fn = function()
            -- WHAT RUNG 0 IS FOR: the weapon a company holding nothing can walk in and buy. Every root
            -- class must have one (tests/class_spec.lua asks the same question from the other side),
            -- and the rung has to stay SMALL. It was the fattest band in the game -- 56 wares against a
            -- mean of 41 -- because the graded spread dealt its bottom share there ON TOP of the
            -- openers, and the first thing a new company met was a wall of eight to ten tiles.
            --
            -- COUNTED IN GEAR, NOT IN ROWS, because the rung holds two different things. A CONSUMABLE
            -- there is standing supply -- the nine draughts the town counter sells all day, un-gated
            -- because a gate on a need is a price on a need (Grade.SLOT_PINS, "standing supply") -- and
            -- the Crucible carries six of the nine, so a row count would read its potion shelf as a wall
            -- of unlocks. What the player meets as a wall is GEAR: blades, coats, trinkets, spells.
            --
            -- An author may still pin a piece of gear here with a reason ("a rock: the cheapest ware in
            -- the arena, and gated by nothing"). What this refuses is the rung filling up by default.
            local MAX_GEAR_PER_HOUSE = 5
            local HOUSES = { "alchemist", "arcanum", "bastion", "cathedral",
                             "colosseum", "hunters_lodge", "undercroft" }
            local unlocked, levels = {}, {}
            for id in pairs(Class.defs) do
                if Class.isRoot(id) then unlocked[id] = true; levels[id] = 0 end
            end

            local fat, unarmed = {}, {}
            for _, vendor in ipairs(HOUSES) do
                local gear, weapon = 0, false
                for _, row in ipairs(Vendor.stock(vendor, 0, nil, unlocked, levels)) do
                    if not row.locked and row.type ~= "consumable" then
                        gear = gear + 1
                        if row.type == "weapon" then weapon = true end
                    end
                end
                if gear > MAX_GEAR_PER_HOUSE then
                    fat[#fat + 1] = string.format("%s opens %d", vendor, gear)
                end
                if not weapon then unarmed[#unarmed + 1] = vendor end
            end
            assert(#unarmed == 0, "no weapon on the opening rung at: " .. table.concat(unarmed, ", ")
                .. " -- a company that lost its kit cannot re-arm there")
            assert(#fat == 0, string.format(
                "the opening rung is a rack again at %s (cap %d pieces of gear a house) -- rung 0 is "
                .. "the re-arm floor, and the graded spread starts above it (tools/grade_report's "
                .. "SHELF_FLOOR)", table.concat(fat, ", "), MAX_GEAR_PER_HOUSE))
        end,
    },

    {
        name = "a house deals fewer wares at the bottom of its ladder than at the top",
        fn = function()
            -- THE CURVE, ASSERTED AS A SHAPE RATHER THAN AS A HISTOGRAM. A company's first morning holds
            -- a few hundred gold and can act on two or three choices; eight is a wall to read rather
            -- than a decision to make. tools/shelf_curve.lua deals a class's stock on a ramp for that
            -- reason and both passes that write `unlockLevel` read it -- but the DATA is what a player
            -- meets, and nothing here would notice a re-spread that flattened it back out.
            --
            -- Quarters rather than rung by rung, because the authored pins move single rungs about on
            -- purpose (the ward line at 3, the seal line at 4) and a case that forbade that would be
            -- asserting the grader's business back at it.
            --
            -- TWO READINGS, AND THE CITY IS THE ONE WITH TEETH. Per house this only catches a real
            -- INVERSION, and the tolerance is there because the thinnest houses do not get their
            -- shallow end from the curve at all: the Crucible carries forty wares of which six are
            -- standing draughts pinned to rung 0 and three are its share of the ward and seal lines,
            -- so what is left for the ramp to shape is about half a shelf. Failing on that would be
            -- re-litigating those pins every time one of them moved, which is the grader's business
            -- and not this case's.
            --
            -- So the ramp itself is asserted across the CITY, where no single house's pins can hide it
            -- and a re-spread back to an even cut has nowhere to go: measured at the seven counters
            -- together, the top quarter of the ladder deals 96 wares against the bottom quarter's 69.
            local MARGIN = 1.15      -- the city's ramp: the top quarter against the bottom
            local HOUSE_SLACK = 1.25 -- what one house may be front-heavy by before it is an inversion

            -- AND A FLOOR IN WARES, BECAUSE A RATIO ON SEVEN IS NOT A MEASUREMENT. The houses run 36
            -- wares to 64, so a quarter is anything from seven rows to twenty -- and on a seven-row
            -- quarter three rows is 43% while on a twenty-row quarter it is noise. A pure ratio
            -- therefore holds the SMALLEST house to the strictest standard, which is backwards: the
            -- thin house is the one whose shape its own tooling cannot reach.
            --
            -- tools/shelf_curve.lua says so in its own header, measured rather than supposed: the ramp
            -- is applied to the SURPLUS above a floor of one per rung, and "the thin houses are already
            -- at one or two a rung and have no surplus left to ramp, which is also why the Undercroft
            -- reads the same at every factor here". Its found half is a flat one per rung by
            -- construction, so what shape it has comes entirely from its priced abilities -- and the
            -- ward line pinned at rung 1 and the seal line at rung 4 are the same in all seven houses
            -- (a family shape, Grade.SLOT_PINS), which in a 36-ware house is four of its front quarter.
            --
            -- ONE WARE PER RUNG is the unit, and the quarter is `q` rungs wide. A front quarter ahead
            -- by less than that is inside the cumulative rounding the ramp is documented to scatter --
            -- shelf_curve's own worked example shows a rung dealing one fewer than the rung under it
            -- at every ramp factor it tried. Below the floor there is nothing for a re-spread to fix;
            -- above it, a genuine inversion still trips BOTH tests and is still named.
            local HOUSE_FLOOR_PER_RUNG = 1
            local HOUSES = { "alchemist", "arcanum", "bastion", "cathedral",
                             "colosseum", "hunters_lodge", "undercroft" }
            local unlocked, levels = {}, {}
            for id in pairs(Class.defs) do
                if Class.isRoot(id) then unlocked[id] = true end
            end

            local q = math.floor((Class.CLASS_LEVEL_CAP + 1) / 4)
            local heavy, cityLow, cityHigh = {}, 0, 0
            for _, vendor in ipairs(HOUSES) do
                local cum = {}
                for rung = 0, Class.CLASS_LEVEL_CAP do
                    for id in pairs(unlocked) do levels[id] = rung end
                    local open = 0
                    for _, row in ipairs(Vendor.stock(vendor, rung, nil, unlocked, levels)) do
                        if not row.locked then open = open + 1 end
                    end
                    cum[rung] = open
                end
                -- The bottom quarter of the ladder against the top quarter, counting only what each
                -- OPENED -- so the opening rack's own rows cannot flatter the front.
                local low = cum[q] - cum[0]
                local high = cum[Class.CLASS_LEVEL_CAP] - cum[Class.CLASS_LEVEL_CAP - q]
                cityLow, cityHigh = cityLow + low, cityHigh + high
                if low > high * HOUSE_SLACK and (low - high) > q * HOUSE_FLOOR_PER_RUNG then
                    heavy[#heavy + 1] = string.format(
                        "%s deals %d over rungs 1-%d and %d over %d-%d (%.2fx, and %d wares ahead " ..
                        "against a floor of %d)", vendor, low, q, high,
                        Class.CLASS_LEVEL_CAP - q + 1, Class.CLASS_LEVEL_CAP, low / math.max(1, high),
                        low - high, q * HOUSE_FLOOR_PER_RUNG)
                end
            end

            assert(#heavy == 0, string.format(
                "%d house(s) deal substantially MORE at the bottom of the ladder than at the top -- a "
                .. "shelf should thicken as it climbs (tools/shelf_curve.lua):\n  %s",
                #heavy, table.concat(heavy, "\n  ")))

            assert(cityHigh >= cityLow * MARGIN, string.format(
                "the city's shelves are flat: %d wares open over the bottom quarter of the ladder and "
                .. "%d over the top, a ratio of %.2f against the %.2f the ramp is cut for. Either "
                .. "tools/shelf_curve.lua's RAMP has been dropped or the passes that read it have not "
                .. "been re-run (`. grade-report apply`, then `. drop-tier apply`).",
                cityLow, cityHigh, cityHigh / math.max(1, cityLow), MARGIN))
        end,
    },
}
