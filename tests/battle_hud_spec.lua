-- THE HUD BAND IS MEASURED, and this is what says so (states/battle.lua's battle.objectiveY /
-- battle.hintY / battle.objectiveRow).
--
-- The band is three rows of centred text -- the fight's name, what wins it, how to work it -- and it is
-- printed into whatever column the host hands over: 608 above a desktop's board, and as little as 188
-- in a handheld's left column. The objective row was laid out by centring text and read-out as one
-- group off a single `print`, which is correct at 608 and silently catastrophic at 188: the group's x
-- came out NEGATIVE, so "Objective: Clear every wave, keep Survivor alive" ran off the side of the
-- screen at one end and printed its wave tally over the board's first tile at the other. Found on a
-- phone, from a screenshot; the suite was green through all of it, and every screen-space spec in this
-- folder was green because none of them ask a widget how wide it drew.
--
-- So these are the two claims the row now makes, asked at the widths that exist:
--   * NOTHING IS DRAWN OUTSIDE THE COLUMN -- every wrapped line fits, and so does the read-out that
--     trails the last one.
--   * THE ROWS UNDER IT MOVE WHEN IT GROWS -- the hint's row is derived from this one's measured
--     height, not from a constant, so a wrapped objective carries the hint (and the deployment phase's
--     headline, and the docked tooltips, and the turn strip) down with it instead of being printed
--     through.
--
-- Fonts are stubbed, as every geometry spec here stubs them (`t.window = false`, so newFont throws) --
-- but this one's stub WRAPS. A stub whose getWrap hands the whole string back as one line cannot fail
-- either claim: it would be measuring the stub. The metric is not the real face's and is not meant to
-- be -- what is under test is the arithmetic around the wrap, and the real typography is what the
-- screenshot in the commit is for.
--
-- states/battle.lua is required here (no other spec does; the rest read its source as text) and it
-- stays in package.loaded carrying these stub fonts, which is harmless only while that remains true.

local function withFonts(fn)
    local gfx = love.graphics
    local real = gfx.newFont
    local face
    face = {
        getHeight = function() return 18 end,
        getWidth = function(_, s) return #tostring(s or "") * 8 end,
        -- Greedy word wrap at `limit`, the contract love's own getWrap keeps: (widest, lines).
        getWrap = function(self, text, limit)
            local lines, line = {}, ""
            for word in tostring(text):gmatch("%S+") do
                local try = (line == "") and word or (line .. " " .. word)
                if line == "" or self:getWidth(try) <= limit then
                    line = try
                else
                    lines[#lines + 1] = line
                    line = word
                end
            end
            lines[#lines + 1] = line
            local widest = 0
            for _, l in ipairs(lines) do widest = math.max(widest, self:getWidth(l)) end
            return widest, lines
        end,
    }
    gfx.newFont = function() return face end
    local ok, err = pcall(fn, face)
    gfx.newFont = real
    if not ok then error(err, 0) end
end

-- The widths the band is actually printed into: the narrowest handheld left column (the 880-wide
-- space Scale clamps a phone to, minus a 448 board and a 244 panel), the ordinary one on a taller
-- handset, and the desktop's band over the board.
local WIDTHS = { 188, 250, 608 }

-- One of each SHAPE the row can take: a bare line, a line with a wave tally, a line with a tick
-- countdown, and the longest sentence Combat.objectiveGoal can build (a win clause plus a protect
-- clause naming a body).
local CASES = {
    { name = "killAll", arena = { type = "killAll", enemy = "every enemy" } },
    { name = "defend + protect", arena = { type = "defend", protect = "character_survivor" } },
    { name = "survive + clock", arena = { type = "survive", enemy = "the tide" },
      combat = { objective = { type = "survive", duration = 30 }, clock = 4 } },
    { name = "reach + protect", arena = { type = "reach", who = "character_caravan_driver",
                                          protect = "character_caravan_master" } },
}

local function battle()
    return require("states.battle")
end

local function apply(b, case)
    b.deploy = false
    b.encounter = { name = "Battle" }
    b.arena = { objective = case.arena }
    b.combat = case.combat
end

return {
    {
        name = "the objective row is drawn inside the column it is handed, at every column width",
        fn = function()
            withFonts(function(face)
                local b = battle()
                for _, case in ipairs(CASES) do
                    apply(b, case)
                    for _, w in ipairs(WIDTHS) do
                        local row = b.objectiveRow(w)
                        assert(#row.lines >= 1, case.name .. " @" .. w .. ": no line at all")
                        for i, line in ipairs(row.lines) do
                            -- The last line carries the read-out unless the read-out took its own,
                            -- so it is the line plus the tail that has to fit.
                            local ink = face:getWidth(line)
                            if i == #row.lines and not row.tailOwnLine then ink = ink + row.tailW end
                            assert(ink <= w, ("%s @%d: line %d is %d wide in a %d column -- it is "
                                .. "drawn off the end of it"):format(case.name, w, i, ink, w))
                        end
                        -- The tail alone on its line is the fallback, and it has to fit too.
                        if row.tailOwnLine then
                            assert(row.tailW - row.gap <= w,
                                case.name .. " @" .. w .. ": the read-out overruns its own line")
                        end
                    end
                end
                b.arena, b.combat, b.encounter = nil, nil, nil
            end)
        end,
    },
    {
        name = "the rows under the objective are placed off its measured height, not a constant",
        fn = function()
            withFonts(function(face)
                local b = battle()
                apply(b, CASES[2]) -- the wave-defend, the line that found this
                -- The narrow column wraps it and the wide one does not, so the hint's row is lower in
                -- the first. If these ever come out equal the band is back on a constant.
                local narrow, wide = b.objectiveRow(188), b.objectiveRow(608)
                assert(#narrow.lines > #wide.lines,
                    "the objective no longer wraps in a 188px column -- this spec is measuring nothing")
                assert(b.hintY(188) > b.hintY(608),
                    "the hint sits at the same row whether the objective wrapped or not -- it is "
                    .. "being printed through the line above it")
                for _, w in ipairs(WIDTHS) do
                    assert(b.hintY(w) >= b.objectiveY(w) + b.objectiveRow(w).h,
                        "the hint's row is inside the objective's block at " .. w)
                    assert(b.objectiveY(w) >= 8 + face:getHeight(),
                        "the objective's row is inside the name's block at " .. w)
                end
                -- ...and the name's own block is measured too: a long name wraps and pushes the
                -- objective down rather than having the objective printed across it.
                b.encounter = { name = "The Long Road Out of the Sunken Quarter" }
                assert(b.objectiveY(188) > b.objectiveY(608),
                    "a name that wraps does not move the objective under it")
                b.arena, b.combat, b.encounter = nil, nil, nil
            end)
        end,
    },
    {
        name = "a tick countdown does not move the band as it counts down",
        fn = function()
            withFonts(function()
                local b = battle()
                -- The read-out's fit is decided against a digit-padded sample of the label, because
                -- the label narrows as the clock runs out ("30" -> "9"). Decided against the label
                -- itself, the tail would pull up onto the line above somewhere around the last few
                -- ticks -- and take every row under it up by a line, mid-fight.
                --
                -- SWEPT, not sampled at the three widths above. The flip only happens where the
                -- line plus the read-out lands within a digit's width of the column's edge, and
                -- whether any given column is in that band is a fact about one sentence in one face
                -- -- pick three widths and the guard passes on a layout that has no padding at all.
                apply(b, CASES[3])
                local heights = {}
                for _, clock in ipairs({ 0, 12, 21, 29 }) do
                    b.combat = { objective = { type = "survive", duration = 30 }, clock = clock }
                    for w = 180, 700 do
                        local h = b.objectiveRow(w).h
                        assert(heights[w] == nil or heights[w] == h,
                            ("the objective band changed height at %d ticks left in a %d column "
                            .. "(%d -> %d): the fight's furniture jumps as the clock runs out")
                            :format(30 - clock, w, heights[w] or -1, h))
                        heights[w] = h
                    end
                end
                b.arena, b.combat, b.encounter = nil, nil, nil
            end)
        end,
    },
}
