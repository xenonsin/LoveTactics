-- Tests for the season table (data/biome_windows.lua) and the window model.
--
-- The load-bearing case is "at least three grounds open every day". Everything else in this file
-- guards a way that invariant can be broken by an edit that looks harmless: an overlapping pair of
-- windows, a biome dropped from the table, a day range that runs past the deadline, a quest naming a
-- ground that no longer has a blueprint.

local BiomeWindow = require("models.biome_window")
local Biome = require("models.biome")
local Calendar = require("models.calendar")
local Quest = require("models.quest")

-- The floor the board stops being a choice of destination below. Named rather than inlined because
-- the failure messages quote it and because it is the number a future retune would move.
local MIN_OPEN = 3

return {
    {
        name = "at least three biomes are open on every one of the forty days",
        fn = function()
            for day = 1, Calendar.DAYS do
                local open = BiomeWindow.openOn(day)
                assert(#open >= MIN_OPEN, string.format(
                    "day %d opens only %d biome(s) (%s) -- the board needs %d",
                    day, #open, table.concat(open, ", "), MIN_OPEN))
            end
        end,
    },
    {
        name = "every scheduled biome has a blueprint in data/biomes",
        fn = function()
            for _, id in ipairs(BiomeWindow.ids()) do
                assert(Biome.defs[id], "data/biome_windows.lua schedules '" .. id ..
                    "', which has no data/biomes/" .. id .. ".lua")
            end
        end,
    },
    {
        name = "every biome with a blueprint is scheduled",
        fn = function()
            for id in pairs(Biome.defs) do
                assert(#BiomeWindow.windows(id) > 0,
                    "biome '" .. id .. "' has a blueprint but no window -- it is unreachable")
            end
        end,
    },
    {
        name = "windows are well formed: in range, ordered, and non-overlapping",
        fn = function()
            for _, id in ipairs(BiomeWindow.ids()) do
                local last = 0
                for i, w in ipairs(BiomeWindow.windows(id)) do
                    assert(type(w[1]) == "number" and type(w[2]) == "number",
                        id .. " window " .. i .. " is not a { first, last } pair")
                    assert(w[1] >= 1 and w[2] <= Calendar.DAYS, string.format(
                        "%s window %d is days %d-%d, outside the %d-day campaign",
                        id, i, w[1], w[2], Calendar.DAYS))
                    assert(w[1] <= w[2], string.format(
                        "%s window %d runs backwards (%d-%d)", id, i, w[1], w[2]))
                    assert(w[1] > last, string.format(
                        "%s window %d (day %d) overlaps or precedes the one before it (ended day %d)",
                        id, i, w[1], last))
                    last = w[2]
                end
            end
        end,
    },
    {
        name = "daysLeft counts today, and is nil while shut",
        fn = function()
            for _, id in ipairs(BiomeWindow.ids()) do
                for _, w in ipairs(BiomeWindow.windows(id)) do
                    assert(BiomeWindow.daysLeft(id, w[2]) == 1,
                        id .. " reads 0 days left on the last morning of a window")
                    assert(BiomeWindow.daysLeft(id, w[1]) == w[2] - w[1] + 1,
                        id .. " miscounts the first morning of a window")
                    if w[2] < Calendar.DAYS and not BiomeWindow.isOpen(id, w[2] + 1) then
                        assert(BiomeWindow.daysLeft(id, w[2] + 1) == nil,
                            id .. " reports days left the morning after it shut")
                    end
                end
            end
        end,
    },
    {
        name = "biomesOf reads the new list, the old single field, and neither",
        fn = function()
            local list = BiomeWindow.biomesOf({ map = { biomes = { "tundra", "castle" } } })
            assert(#list == 2 and list[1] == "tundra" and list[2] == "castle", "list form not read")
            -- The 92 files still authoring a single `biome` must keep working through the migration.
            local single = BiomeWindow.biomesOf({ map = { biome = "swamp" } })
            assert(#single == 1 and single[1] == "swamp", "single form not read")
            assert(#BiomeWindow.biomesOf({ map = {} }) == 0, "a map naming no ground should read empty")
            assert(#BiomeWindow.biomesOf({}) == 0, "a def with no map should read empty")
            -- The returned list is a copy: the board sorts and filters it, and the blueprint is shared.
            local def = { map = { biomes = { "swamp" } } }
            BiomeWindow.biomesOf(def)[1] = "volcanic"
            assert(def.map.biomes[1] == "swamp", "biomesOf handed out the blueprint's own table")
        end,
    },
    {
        name = "a quest is takeable exactly on the days one of its grounds is open",
        fn = function()
            local def = { map = { biomes = { "swamp" } } }
            for day = 1, Calendar.DAYS do
                assert(BiomeWindow.available(def, day) == BiomeWindow.isOpen("swamp", day),
                    "swamp quest availability disagrees with the swamp window on day " .. day)
            end
        end,
    },
    {
        name = "a quest naming two grounds is takeable while either is open",
        fn = function()
            local def = { map = { biomes = { "swamp", "castle" } } }
            local reachable = 0
            for day = 1, Calendar.DAYS do
                local both = BiomeWindow.isOpen("swamp", day) or BiomeWindow.isOpen("castle", day)
                assert(BiomeWindow.available(def, day) == both, "two-ground quest wrong on day " .. day)
                if both then reachable = reachable + 1 end
            end
            -- The point of the set: widening a quest strictly ADDS days it can be run.
            local narrow = 0
            for day = 1, Calendar.DAYS do
                if BiomeWindow.isOpen("swamp", day) then narrow = narrow + 1 end
            end
            assert(reachable > narrow, "widening a quest to a second ground bought it no extra days")
        end,
    },
    {
        name = "destinations only ever name grounds that are open",
        fn = function()
            local def = { map = { biomes = { "swamp", "castle", "tundra" } } }
            for day = 1, Calendar.DAYS do
                for _, id in ipairs(BiomeWindow.destinations(def, day)) do
                    assert(BiomeWindow.isOpen(id, day),
                        "day " .. day .. ": offered a run to " .. id .. ", which is shut")
                end
            end
        end,
    },
    {
        name = "a quest naming no ground is reachable from every open one",
        fn = function()
            local def = { map = {} }
            for day = 1, Calendar.DAYS do
                local open = BiomeWindow.openOn(day)
                assert(#BiomeWindow.destinations(def, day) == #open,
                    "a quest naming no ground was filtered on day " .. day)
            end
        end,
    },
    {
        name = "the finale ignores the schedule outright",
        fn = function()
            -- The one exemption that matters: a season table must never be able to hide the ending.
            local def = { finale = true, map = { biomes = { "underworld" } } }
            for day = 1, Calendar.DAYS do
                assert(BiomeWindow.available(def, day),
                    "the finale was gated by the biome schedule on day " .. day)
            end
            -- Including when its ground is not in the table at all.
            local orphan = { finale = true, map = { biomes = { "__no_such_ground" } } }
            assert(BiomeWindow.available(orphan, 1), "a finale on an unscheduled ground vanished")
        end,
    },
    {
        name = "the shipped finale is the only quest exempt from the schedule",
        fn = function()
            local exempt = {}
            for id, def in pairs(Quest.defs) do
                if def.finale then exempt[#exempt + 1] = id end
            end
            assert(#exempt == 1, "expected exactly one finale, found " .. #exempt)
        end,
    },
    {
        -- THE REGRESSION THAT MATTERS, and the only one the table's own shape cannot catch. A
        -- schedule can be perfectly well formed -- three grounds open every day, no overlaps, every
        -- biome scheduled -- and still strand the player, because what a ground HOLDS on day 12 is a
        -- function of how far each house's chain has got by then. The first draft of the table passed
        -- every other case in this file while leaving days 1-9 unplayable.
        --
        -- Walked through tools/biome_report.lua rather than reimplemented, so the spec and the
        -- instrument can never disagree about what "blocked" means (tests/progression_report_spec.lua
        -- takes the same route for the same reason).
        name = "no play policy is ever left with nothing it can reach",
        fn = function()
            local Report = require("tools.biome_report")
            for _, policy in ipairs(Report.POLICIES) do
                local r = Report.walk(policy.id)
                local base = Report.walk(policy.id, false, true)
                assert(r.blocked == 0, string.format(
                    "the '%s' policy is blocked on %d day(s) -- run `. biome-report` for the worklist",
                    policy.id, r.blocked))
                -- A window may decide WHERE a day is spent; it must never cost the day itself.
                assert(r.ran >= base.ran, string.format(
                    "the schedule cost the '%s' policy %d expedition(s) against a no-window baseline",
                    policy.id, base.ran - r.ran))
            end
        end,
    },
    {
        name = "every ground named by a shipped quest has a blueprint and a window",
        fn = function()
            for id, def in pairs(Quest.defs) do
                for _, biomeId in ipairs(BiomeWindow.biomesOf(def)) do
                    assert(Biome.defs[biomeId], id .. " names biome '" .. biomeId ..
                        "', which has no data/biomes/" .. biomeId .. ".lua")
                    assert(#BiomeWindow.windows(biomeId) > 0, id .. " names biome '" .. biomeId ..
                        "', which is never open")
                end
            end
        end,
    },
}
