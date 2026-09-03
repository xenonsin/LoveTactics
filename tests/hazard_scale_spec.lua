-- WHAT A HAZARD COSTS IS STATED IN THE FLOOR'S OWN UNITS, and this is the guard on that.
--
-- The four descent hazards (models/descent.lua's Descent.HAZARDS) were tuned against a 40x40 board of
-- tiles -- 931 walkable, a forty-step crossing -- and their numbers were literals in states/game.lua:
-- the Turning Floor unlearned a 13x13 block, the Translation wanted somewhere eight steps off, the Dark
-- ran thirty steps. Every one of those reads as "a neighbourhood", "a long way" and "a stretch" on that
-- board.
--
-- A floor is a 10x10 grid of PLACES now, crossed in about eighteen steps, and the same three numbers
-- mean: unlearn the whole floor, look for somewhere further away than the floor is wide, and walk blind
-- for two crossings. Measured on a fully-walked floor before the fix, one Turning Floor took the known
-- cells from 97 to 44 -- and took the WAY UP with them, which in a mode whose only bank is the stair you
-- came down by is a lost run with no fight in it.
--
-- TWO KINDS OF NUMBER, and the split is the lesson this file exists to keep. A cost that means "around
-- you" is LOCAL and must not be a share of the floor -- that is how a 6 gets written and then quietly
-- becomes everything. A cost that means "for a while" is a DURATION and must be a share, or it stops
-- meaning anything the moment the floor changes size. Both are asserted below, and the handlers are
-- scanned to make sure they still read them rather than carrying literals again.

local Descent = require("models.descent")

local SRC = "states/game.lua"

local function source()
    return assert(love.filesystem.read(SRC), "should be able to read " .. SRC)
end

-- A floor-shaped stand-in. Only cols/rows are read by the derivations.
local function floor(cols, rows)
    return { cols = cols, rows = rows or cols }
end

return {
    {
        name = "the turning floor takes a neighbourhood, not the floor",
        fn = function()
            local r = Descent.SPINNER_RADIUS
            assert(r >= 1, "a spinner that unlearns nothing is not a hazard")

            -- The disc it clears, against the places a floor actually holds. A quarter is the line: past
            -- that it stops being "the ground around the company" and becomes the map.
            for _, span in ipairs({ 10, 11, 12 }) do
                local cells = span * span
                -- Places, not cells: about three quarters of the grid is walkable
                -- (Overworld.BLOCK_SHARE).
                local places = cells * 0.75
                local disc = (2 * r + 1) ^ 2
                assert(disc <= places * 0.35, string.format(
                    "on a %dx%d floor a spinner clears %d cells of about %.0f places -- that is the map, "
                    .. "not a neighbourhood", span, span, disc, places))
            end

            -- ...and it is FLAT. A local cost must not grow with the floor, or it is a share wearing a
            -- constant's clothes -- which is exactly what the 6 turned out to be.
            assert(type(Descent.SPINNER_RADIUS) == "number",
                "the spinner radius is a plain number, not a function of the floor")
        end,
    },
    {
        name = "the turning floor never takes the way up",
        fn = function()
            assert(Descent.SPINNER_SPARES_EXIT,
                "the exit is the run's bank, not bearings: walking out is free and the risk is meant "
                .. "to be losing a FIGHT (docs/overworld.md, Getting out)")
            -- ...and the handler honours it. Source-scanned because the hazard resolves inside the game
            -- state, which cannot be stood up headlessly -- and because what is being guarded is that
            -- a future edit to the loop does not drop the exemption while leaving the flag.
            local src = source()
            assert(src:find("SPINNER_SPARES_EXIT", 1, true),
                "states/game.lua's spinner does not read the exemption")
            assert(src:find("Descent.SPINNER_RADIUS", 1, true),
                "states/game.lua's spinner is back to carrying its own radius")
            assert(not src:find("local r = 6", 1, true),
                "the old tile-board radius is back")
        end,
    },
    {
        name = "the dark and the translation scale with the floor they are on",
        fn = function()
            -- Durations and distances DO scale: a stretch of walking means a stretch of THIS floor.
            local small, big = floor(10), floor(12)
            assert(Descent.darkSteps(big) > Descent.darkSteps(small),
                "a bigger floor should be dark for longer -- the cost is a share of the crossing")
            assert(Descent.translationMin(big) > Descent.translationMin(small),
                "a bigger floor should throw you further")

            -- ...and neither may exceed the floor. A dark that outlasts the sitting or a throw that
            -- wants somewhere further off than the floor is wide are the two failures this replaced.
            for _, span in ipairs({ 10, 11, 12 }) do
                local f = floor(span)
                local crossing = span + span -- the Manhattan span, an upper bound on any walk
                assert(Descent.darkSteps(f) <= crossing, string.format(
                    "on %dx%d the dark runs %d steps against a %d-step crossing",
                    span, span, Descent.darkSteps(f), crossing))
                assert(Descent.translationMin(f) < crossing, string.format(
                    "on %dx%d the translation wants %d steps of separation, and the floor only has %d",
                    span, span, Descent.translationMin(f), crossing))
            end

            -- The handlers read them rather than carrying the old literals.
            local src = source()
            assert(src:find("Descent.darkSteps(game.grid)", 1, true),
                "the dark is back to a fixed number of steps")
            assert(src:find("Descent.translationMin(game.grid)", 1, true),
                "the translation is back to a fixed distance")
        end,
    },
    {
        name = "the translation always lands somewhere -- it relaxes rather than no-opping",
        fn = function()
            -- A hazard that usually reports nothing happened is one the player learns to ignore, which
            -- is worse than not having it. The handler walks its distance down until something
            -- qualifies; this is the shape of that loop, scanned.
            local src = source()
            local i = src:find("THE TRANSLATION", 1, true)
            assert(i, "the translation handler was not found -- re-anchor this case")
            local block = src:sub(i, i + 2600)
            assert(block:find("while #seen == 0", 1, true),
                "the translation no longer relaxes: on a floor with nowhere far enough it will go back "
                .. "to reporting that nothing happened")
        end,
    },
}
