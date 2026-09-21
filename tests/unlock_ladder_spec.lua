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
            -- Rung 0 is allowed to be the fat one: it is the opening rack, held from the first
            -- morning, and it is the one rung no floor pays (models/spoils.lua's rankBand reaches
            -- down to it and never centres on it).
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
}
