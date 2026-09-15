-- Tests for the season table (data/biome_windows.lua) and the window model.
--
-- The load-bearing case is "at least three grounds open every day". Everything else here guards a way
-- that invariant can be broken by an edit that looks harmless: an overlapping pair of windows, a biome
-- dropped from the table, a day range that runs past the season, a ground with no blueprint.
--
-- WHAT THIS FILE USED TO ALSO TEST, and no longer does: which QUESTS a day's open grounds made
-- takeable. `Quest.available` and `Quest.board` went with the old board, and the season now gates the
-- houses posting on the bounty board instead (models/bounty.lua's offered). Those cases are not
-- weakened versions of the old ones -- they are cases about a system that no longer exists, and the
-- rotation's own coverage lives in tests/bounty_spec.lua where the thing being rotated lives.

local BiomeWindow = require("models.biome_window")
local Biome = require("models.biome")

-- The floor the board stops being a choice of destination below. Named rather than inlined because the
-- failure messages quote it and because it is the number a future retune would move.
local MIN_OPEN = 3

return {
    {
        name = "at least three grounds are open on every day of the season",
        fn = function()
            for day = 1, BiomeWindow.SEASON do
                local open = BiomeWindow.openOn(day)
                assert(#open >= MIN_OPEN, string.format(
                    "day %d opens only %d ground(s) (%s) -- the board needs %d",
                    day, #open, table.concat(open, ", "), MIN_OPEN))
            end
        end,
    },
    {
        -- The season repeats rather than running out, because the deadline it was authored against is
        -- retired. A day past the end that opened nothing would be a board with no work on it.
        name = "the season repeats, and a day past its end reads as a day inside it",
        fn = function()
            for day = 1, BiomeWindow.SEASON do
                local wrapped = day + BiomeWindow.SEASON * 3
                assert(BiomeWindow.seasonDay(wrapped) == day,
                    "day " .. wrapped .. " did not wrap back onto day " .. day)
                local a = table.concat(BiomeWindow.openOn(day), ",")
                local b = table.concat(BiomeWindow.openOn(wrapped), ",")
                assert(a == b, "the season deals a different board on its second lap at day " .. day)
            end
            -- ...and the wrap is one-based: the last day of a season is the table's last row, not its
            -- first, which an off-by-one here would silently swap.
            assert(BiomeWindow.seasonDay(BiomeWindow.SEASON) == BiomeWindow.SEASON,
                "the last day of a season wrapped to the first")
            assert(BiomeWindow.seasonDay(BiomeWindow.SEASON + 1) == 1,
                "the season did not come round to day one")
        end,
    },
    {
        name = "every scheduled ground has a blueprint, and every blueprint is scheduled",
        fn = function()
            for _, id in ipairs(BiomeWindow.ids()) do
                assert(Biome.defs[id], "the schedule names a ground with no blueprint: " .. id)
            end
            for id in pairs(Biome.defs) do
                assert(#BiomeWindow.windows(id) > 0,
                    id .. " has a blueprint and no window, so nothing can ever be posted there")
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
                        id .. " window " .. i .. " is not a pair of days")
                    assert(w[1] >= 1 and w[2] <= BiomeWindow.SEASON,
                        id .. " window " .. i .. " runs outside the season")
                    assert(w[1] <= w[2], id .. " window " .. i .. " ends before it starts")
                    assert(w[1] > last, id .. " window " .. i .. " overlaps the one before it")
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
                        id .. " says something other than one day left on its last morning")
                    assert(BiomeWindow.daysLeft(id, w[1]) == w[2] - w[1] + 1,
                        id .. " miscounts the days left on its first morning")
                    if w[1] > 1 and not BiomeWindow.isOpen(id, w[1] - 1) then
                        assert(BiomeWindow.daysLeft(id, w[1] - 1) == nil,
                            id .. " counts days left on a day it is shut")
                    end
                end
            end
        end,
    },
}
