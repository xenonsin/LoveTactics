-- The reference block that defines whatever an item screen NAMES: one short line for every status the
-- item can inflict and every keyword its ability declares (models/glossary.lua gathers them).
--
-- It exists because an item's own text names things it does not explain -- "Applies: Rimebitten", a
-- `frenzy` arc -- and the player reading that row has nowhere to go and look the word up. Rather than
-- a hover-inside-a-hover, which no gamepad or keyboard could ever reach, the definitions simply appear
-- ALONGSIDE what named them: one hover, everything it needs. That also keeps the project's three-input
-- standard intact for free, since there is no second thing to point at.
--
-- Two surfaces, one body of rows:
--
--   GlossaryPanel.draw(entries, box, maxRight)        -- a floating box beside an item TOOLTIP
--                                                     -- (box = the tooltip's { x, y, w, h })
--   GlossaryPanel.drawColumn(entries, x, y, w, maxH, opts) -> height used
--                                                     -- bare rows inside a panel's own detail column
--
-- `draw` is the hover case (ui/item_tooltip.lua): its own dark box, on whichever side of the tooltip
-- has room, and no heading -- a box beside a tooltip holding nothing but definitions does not need a
-- line telling the player it is definitions. `drawColumn` is the docked case (ui/panels/shop.lua): no
-- chrome, because the column it lands in already has some, but it DOES take the heading, since it sits
-- under a stat block and would otherwise read as more stats. The host passes its own fonts so the
-- block matches the type around it. Both cut the list short and say how many they dropped rather than overrunning the room they were
-- given, and both measure with exactly the layout they draw with -- one pass disagreeing with the
-- other is how a block silently starts overlapping what sits beneath it.

local Scale = require("scale")

local W = 226   -- the floating box's width: narrower than the tooltip (244), since this is the aside
local PAD = 8
local GAP = 8   -- between the tooltip's edge and the floating box's
local ENTRY_GAP = 7 -- between one definition and the next, in the airy form
local COMPACT_GAP = 4 -- ... and in the compact one, where the paragraphs are already distinct by tint
local TAG_GAP = 6   -- least space kept between an entry's name and its STATUS/KEYWORD tag

local GlossaryPanel = {}

local BG = { 0.07, 0.08, 0.11, 0.96 }
local BORDER = { 0.34, 0.37, 0.45, 0.85 } -- muted, unlike the tooltip's type-tinted edge: this is secondary
local CAPTION = { 0.55, 0.58, 0.66 }
local TAG = { 0.48, 0.52, 0.60 }
local DESC = { 0.78, 0.80, 0.86 }
local MUTED = { 0.62, 0.65, 0.72 }
local KIND_LABEL = { status = "STATUS", keyword = "KEYWORD" }

local nameFont, descFont, capFont
local function defaultFonts()
    nameFont = nameFont or love.graphics.newFont(12)
    descFont = descFont or love.graphics.newFont(11)
    capFont = capFont or love.graphics.newFont(10)
    return nameFont, descFont, capFont
end

-- The three faces this block renders with: the host's, where it gave them (so a docked block matches
-- the column's own type scale), else the tooltip-sized defaults.
local function facesFor(opts)
    local n, d, c = defaultFonts()
    opts = opts or {}
    return opts.nameFont or n, opts.descFont or d, opts.capFont or c
end

-- One entry as a single flowing paragraph -- the name in its own tint, the description running on from
-- it -- for the compact form. LÖVE's coloured-text table is what makes that one printf rather than a
-- hand-rolled indent, and `Font:getWrap` measures the same table, so the two passes cannot disagree.
local function compactText(entry)
    local col = entry.color or MUTED
    local body = entry.description
    if not body or body == "" then body = KIND_LABEL[entry.kind] and KIND_LABEL[entry.kind]:lower() or "" end
    return { { col[1], col[2], col[3] }, entry.name, DESC, "  " .. body }
end

-- Lay out as many entries as fit in `maxH`, measuring each exactly as the draw pass will render it.
-- Two forms, chosen by `compact`:
--   airy (the floating box) -- the name on its own line beside a STATUS/KEYWORD tag, description under
--   compact (a docked column) -- name and description as one wrapped paragraph, in the description's
--                                face, which is what lets a full list fit a panel's spare inches
-- `caption` adds the GLOSSARY heading; see the note on `paint` for when a block wants one.
-- Returns the laid-out rows, the height they consume (caption included), and how many entries were
-- dropped for want of room.
local function layout(entries, innerW, maxH, name, desc, cap, compact, caption)
    local nameH, descH, capH = name:getHeight(), desc:getHeight(), cap:getHeight()
    local h = caption and (capH + 5) or 0
    local footerH = descH + 3
    local gapH = compact and COMPACT_GAP or ENTRY_GAP
    local rows, dropped = {}, 0

    for i, entry in ipairs(entries) do
        local row = { entry = entry, nameLines = 0, descLines = 0 }
        if compact then
            row.text = compactText(entry)
            local _, lines = desc:getWrap(row.text, innerW)
            row.height = math.max(1, #lines) * descH
        else
            local tagW = cap:getWidth(KIND_LABEL[entry.kind] or "")
            row.nameW = math.max(1, innerW - tagW - TAG_GAP)
            local _, nameLines = name:getWrap(entry.name, row.nameW)
            row.nameLines = math.max(1, #nameLines)
            if entry.description and entry.description ~= "" then
                local _, lines = desc:getWrap(entry.description, innerW)
                row.descLines = math.max(1, #lines)
            end
            row.height = row.nameLines * nameH + 1 + row.descLines * descH
        end
        local gap = (i > 1) and gapH or 0
        -- Only commit the row if what remains still leaves room for the footer, so a truncated list can
        -- always say so. The last entry needs no footer, hence the `i < #entries` on that reserve.
        local reserve = (i < #entries) and footerH or 0
        if h + gap + row.height + reserve <= maxH then
            h = h + gap + row.height
            rows[#rows + 1] = row
        else
            dropped = #entries - i + 1
            break
        end
    end

    if dropped > 0 then h = h + footerH end
    return rows, h, dropped
end

-- Paint the committed rows at (x, y) in a `w`-wide column. Split out so the floating box and the
-- docked column render from one body of code and can never drift apart.
--
-- `caption` prints the GLOSSARY heading above them. A DOCKED block wants one -- it lands under a stat
-- block inside a pane that is already full of the item's own numbers, and without a heading the
-- definitions read as more of those. The floating box does not: it is a panel of its own beside the
-- tooltip, holding nothing else, so the heading only spends a line saying what the box plainly is.
local function paint(rows, dropped, x, y, w, name, desc, cap, compact, caption)
    local nameH, descH, capH = name:getHeight(), desc:getHeight(), cap:getHeight()
    local gapH = compact and COMPACT_GAP or ENTRY_GAP
    local ty = y

    if caption then
        love.graphics.setFont(cap)
        love.graphics.setColor(CAPTION[1], CAPTION[2], CAPTION[3], 1)
        love.graphics.print("GLOSSARY", x, ty)
        ty = ty + capH + 5
    end

    for i, row in ipairs(rows) do
        if i > 1 then ty = ty + gapH end
        local entry = row.entry
        -- The name in the status's own badge tint, so the word here and the badge on the board are
        -- visibly the same thing; keywords share one cool tint, since they have no badge to match.
        local col = entry.color or MUTED
        if compact then
            love.graphics.setFont(desc)
            love.graphics.setColor(1, 1, 1, 1) -- the coloured-text table carries its own tints
            love.graphics.printf(row.text, x, ty, w, "left")
            ty = ty + row.height
        else
            love.graphics.setFont(name)
            love.graphics.setColor(col[1], col[2], col[3], 1)
            love.graphics.printf(entry.name, x, ty, row.nameW, "left")
            love.graphics.setFont(cap)
            love.graphics.setColor(TAG[1], TAG[2], TAG[3], 1)
            love.graphics.printf(KIND_LABEL[entry.kind] or "", x, ty + 1, w, "right")
            ty = ty + row.nameLines * nameH + 1
            if row.descLines > 0 then
                love.graphics.setFont(desc)
                love.graphics.setColor(DESC[1], DESC[2], DESC[3], 1)
                love.graphics.printf(entry.description, x, ty, w, "left")
                ty = ty + row.descLines * descH
            end
        end
    end

    if dropped > 0 then
        love.graphics.setFont(desc)
        love.graphics.setColor(MUTED[1], MUTED[2], MUTED[3], 1)
        love.graphics.print("+" .. dropped .. " more", x, ty + 3)
    end
end

-- Where the floating box sits: beside the tooltip on whichever side has room, top-aligned with it.
-- Prefers the right, falls back to the left, and when neither side can hold it whole takes the roomier
-- one and clamps -- an overlap at the screen's edge beats a panel drawn off it.
local function position(box, h, maxRight)
    local rightX, leftX = box.x + box.w + GAP, box.x - GAP - W
    local x
    if rightX + W <= maxRight - 4 then
        x = rightX
    elseif leftX >= 4 then
        x = leftX
    elseif (maxRight - (box.x + box.w)) >= box.x then
        x = math.min(rightX, maxRight - W - 4)
    else
        x = math.max(4, leftX)
    end
    x = math.max(4, math.min(x, maxRight - W - 4))
    local y = math.max(4, math.min(box.y, Scale.HEIGHT - h - 4))
    return x, y
end

-- Draw the definitions for `entries` beside the tooltip occupying `box` = { x, y, w, h }. `maxRight`
-- caps the box's right edge the same way the tooltip's does (defaults to the screen width). No-op for
-- an item that names no status and declares no keyword, which is most of them.
function GlossaryPanel.draw(entries, box, maxRight)
    if not entries or #entries == 0 or not box then return end
    local name, desc, cap = defaultFonts()
    maxRight = maxRight or Scale.WIDTH

    local innerW = W - PAD * 2
    local rows, h, dropped = layout(entries, innerW, Scale.HEIGHT - 8 - PAD * 2, name, desc, cap,
        false, false)
    if #rows == 0 then return end
    h = h + PAD * 2
    local bx, by = position(box, h, maxRight)

    love.graphics.setColor(BG)
    love.graphics.rectangle("fill", bx, by, W, h, 6, 6)
    love.graphics.setColor(BORDER)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", bx, by, W, h, 6, 6)

    paint(rows, dropped, bx + PAD, by + PAD, innerW, name, desc, cap, false, false)
    love.graphics.setColor(1, 1, 1)
end

-- Draw the definitions as bare rows in a `w`-wide column at (x, y), inside a panel that already has its
-- own frame. `maxH` is the room available beneath -- whatever is left between the block above and
-- whatever comes next -- and is never exceeded: entries that do not fit are dropped for a "+n more".
-- `opts.nameFont` / `.descFont` / `.capFont` let the host lend its own type scale.
--
-- Compact by default -- name and description run together as one tinted paragraph -- because a docked
-- column is spare inches between two other blocks, and the airy form would spend them on three entries'
-- worth of blank line. `opts.airy` asks for the floating box's roomier shape instead, and
-- `opts.caption = false` drops the GLOSSARY heading for a column that is already labelled.
--
-- Returns the height actually consumed (0 when there is nothing to say, or no room to say it in), so a
-- caller laying out its own column can advance past the block.
function GlossaryPanel.drawColumn(entries, x, y, w, maxH, opts)
    if not entries or #entries == 0 then return 0 end
    local name, desc, cap = facesFor(opts)
    local compact = not (opts and opts.airy)
    local caption = not (opts and opts.caption == false)
    local rows, h, dropped = layout(entries, w, maxH or math.huge, name, desc, cap, compact, caption)
    if #rows == 0 then return 0 end
    paint(rows, dropped, x, y, w, name, desc, cap, compact, caption)
    love.graphics.setColor(1, 1, 1)
    return h
end

return GlossaryPanel
