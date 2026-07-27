-- Growth ladder: an item's whole upgrade path drawn as a level-by-level table, one row per level
-- (0..MAX) and one column per stat that actually MOVES across the path. It replaces the old bar-chart
-- "skyline" (which asked you to read gains off bar heights) with the real numbers: you see exactly what
-- each level grants, where you are now, what the next step buys, and where it ends up.
--
-- The same widget serves the Blacksmith (weapons/armor) and every vendor's Upgrade tab (abilities and
-- refined consumables), because Item.growth bakes the curve the same way for all of them.
--
--   GrowthLadder.draw(growth, x, y, w, h, {
--       current   = item.level,     -- the row marked "now" (gold)
--       nextLevel = item.level + 1, -- the row the upgrade button buys (green); nil at max
--       lockedFrom = 5,             -- first rank-gated level; that row and up are dimmed (nil = none)
--       rowFont = font, headFont = font,
--   })
--
-- Only the moving stats get columns; a stat that never changes is not part of the "path" and belongs
-- in the flat stat block the caller draws elsewhere. When the band is too short for every level, the
-- ladder WINDOWS itself -- the levels around "now" and "next", a collapsed gap, then the max pinned as
-- the destination -- so it fits any height without overflowing. Too-many stat columns collapse the
-- overflow into a "+n" note on the last header.

local GrowthLadder = {}

-- Semantic palette, matched to the forge/vendor detail panes.
local MARK   = { 0.95, 0.85, 0.55 } -- the current level ("now")
local NEXT   = { 0.55, 0.90, 0.58 } -- the level the button buys
local OWNED  = { 0.72, 0.77, 0.88 } -- a level already passed
local FUTURE = { 0.52, 0.56, 0.66 } -- a level not yet reached
local LOCKED = { 0.40, 0.36, 0.40 } -- a level gated behind higher standing
local STEP   = { 0.95, 0.95, 0.98 } -- a cell whose value stepped UP at this level
local DIM    = { 0.55, 0.60, 0.70 } -- headers / captions

local LVL_W = 52          -- the level-label column (leaves a gutter for the "now" marker)
local MARK_GUTTER = 10    -- room at the column's left edge for the current-row triangle
local MIN_COL_W = 62      -- narrowest a stat column may be before it is dropped
local MIN_ROW_H, MAX_ROW_H = 12, 18
local GAP = -1            -- sentinel in the visible list: a collapsed "..." run

-- Fit a label into `maxW` by trimming and appending an ellipsis; returns it unchanged if it already fits.
local function ellipsize(font, label, maxW)
    if font:getWidth(label) <= maxW then return label end
    while #label > 1 and font:getWidth(label .. "\226\128\166") > maxW do
        label = label:sub(1, #label - 1)
    end
    return label .. "\226\128\166"
end

-- Pick which moving stats get a column: the primary first, then the rest in order, capped to what fits.
local function chooseColumns(stats, statsW)
    local maxCols = math.max(1, math.floor(statsW / MIN_COL_W))
    local ordered = {}
    for _, s in ipairs(stats) do if s.primary then ordered[#ordered + 1] = s end end
    for _, s in ipairs(stats) do if not s.primary then ordered[#ordered + 1] = s end end
    local shown = {}
    for i = 1, math.min(#ordered, maxCols) do shown[i] = ordered[i] end
    return shown, #ordered - #shown
end

-- The levels to draw, sized to `capacity` rows. When they all fit it is simply 0..maxLevel; otherwise
-- it is a window around now/next, a GAP sentinel, then the max pinned as the destination.
local function visibleLevels(maxLevel, current, nextLevel, capacity)
    if maxLevel + 1 <= capacity then
        local v = {}
        for l = 0, maxLevel do v[#v + 1] = l end
        return v
    end
    -- Not everything fits. If the focus is near the top, just show the last `capacity` levels solid.
    local focus = math.min(current or 0, nextLevel or maxLevel)
    local near = math.max(1, capacity - 2) -- reserve two rows for the gap + pinned max
    local start = math.max(0, focus - 1)
    if start + near - 1 >= maxLevel - 1 then
        local s = math.max(0, maxLevel - capacity + 1)
        local v = {}
        for l = s, maxLevel do v[#v + 1] = l end
        return v
    end
    local v = {}
    for l = start, start + near - 1 do v[#v + 1] = l end
    v[#v + 1] = GAP
    v[#v + 1] = maxLevel
    return v
end

-- Draw the ladder. Returns the y just below the table so a caller can stack a note beneath it.
function GrowthLadder.draw(growth, x, y, w, h, opts)
    opts = opts or {}
    local stats = (growth and growth.stats) or {}
    local maxLevel = (growth and growth.maxLevel) or 0
    local current = opts.current or 0
    local nextLevel = opts.nextLevel
    local lockedFrom = opts.lockedFrom
    local rowFont = opts.rowFont or love.graphics.getFont()
    local headFont = opts.headFont or rowFont

    if #stats == 0 then
        love.graphics.setFont(rowFont)
        love.graphics.setColor(DIM[1], DIM[2], DIM[3])
        love.graphics.print("This piece has no scaling stat to chart.", x, y)
        return y + rowFont:getHeight()
    end

    -- Size rows to the band: window the levels so they always fit, then split the height evenly.
    local capacity = math.max(1, math.floor(h / MIN_ROW_H) - 1) -- -1 for the header row
    local visible = visibleLevels(maxLevel, current, nextLevel, capacity)
    local rowH = math.max(MIN_ROW_H, math.min(MAX_ROW_H, math.floor(h / (#visible + 1))))

    local labelX = x + MARK_GUTTER
    local statsX = x + LVL_W
    local statsW = w - LVL_W
    local shown, overflow = chooseColumns(stats, statsW)
    local colW = statsW / #shown
    local pad = 6

    -- Header: LVL, each stat label right-aligned over its column, and an overflow note if some dropped.
    love.graphics.setFont(headFont)
    love.graphics.setColor(DIM[1], DIM[2], DIM[3])
    love.graphics.print("LVL", labelX, y)
    for i, s in ipairs(shown) do
        local cx = statsX + (i - 1) * colW
        local label = s.label
        if overflow > 0 and i == #shown then label = label .. " +" .. overflow end
        love.graphics.printf(ellipsize(headFont, label, colW - pad), cx, y, colW - pad, "right")
    end

    local topY = y + rowH
    for i, lvl in ipairs(visible) do
        local rowY = topY + (i - 1) * rowH
        local textY = rowY + (rowH - rowFont:getHeight()) / 2

        if lvl == GAP then
            love.graphics.setFont(rowFont)
            love.graphics.setColor(DIM[1], DIM[2], DIM[3])
            love.graphics.printf("\226\139\174", x, textY, w, "center") -- vertical ellipsis
        else
            local locked = lockedFrom and lvl >= lockedFrom
            local isNow = (lvl == current)
            local isNext = (lvl == nextLevel)

            -- Row tint behind the two rows that matter: where you are, and where the button takes you.
            if isNow or isNext then
                local t = isNow and MARK or NEXT
                love.graphics.setColor(t[1], t[2], t[3], 0.16)
                love.graphics.rectangle("fill", x - 2, rowY - 1, w + 4, rowH, 3, 3)
            end

            local labelCol = isNow and MARK or isNext and NEXT or locked and LOCKED
                or lvl < current and OWNED or FUTURE

            -- A drawn triangle marks the current row -- font-independent, so it reads without colour alone.
            if isNow then
                local ty = rowY + rowH / 2
                love.graphics.setColor(MARK[1], MARK[2], MARK[3])
                love.graphics.polygon("fill", x, ty - 4, x + 6, ty, x, ty + 4)
            end

            love.graphics.setFont(rowFont)
            love.graphics.setColor(labelCol[1], labelCol[2], labelCol[3])
            love.graphics.print("+" .. lvl, labelX, textY)

            for si, s in ipairs(shown) do
                local v = s.values[lvl]
                local cx = statsX + (si - 1) * colW
                local col
                if locked then col = LOCKED
                elseif s.changed[lvl] then col = STEP    -- stepped up here: the level's actual gain
                elseif isNow then col = MARK
                elseif isNext then col = NEXT
                elseif lvl < current then col = OWNED
                else col = FUTURE end
                love.graphics.setColor(col[1], col[2], col[3])
                local text = v ~= nil and tostring(v) or "\226\128\147"
                love.graphics.printf(text, cx, textY, colW - pad, "right")
            end
        end
    end

    return topY + #visible * rowH
end

return GrowthLadder
