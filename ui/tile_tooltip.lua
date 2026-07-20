-- Shared hover tooltip for a battlefield tile: a dark panel showing the tile's terrain type,
-- its movement / line-of-sight / positional modifiers, and — when something stands on it — the
-- occupant's details. A unit shows its side, resource pools (HP / mana / stamina bars) and combat
-- stats; a revealed trap shows its owner and remaining health. Positioned near the mouse and
-- clamped on-screen, mirroring ui/item_tooltip.lua and ui/status_tooltip.lua.
--
--   TileTooltip.draw(info, mx, my, maxRight)
--     info = { cell = <arena tile>, bonus = <fieldBonus bag>, unit = <combat unit|nil>,
--              trap = <revealed trap|nil> }
--
-- Content is assembled once into an ordered list of blocks that is both measured and drawn, so the
-- computed box height can never drift from what's rendered. No love.graphics at require-time.

local Scale = require("scale")
local Combat = require("models.combat")
local Trap = require("models.trap")
local Colors = require("ui.colors")
local Glyphs = require("ui.glyphs")

local TileTooltip = {}

local titleFont, bodyFont, smallFont
local function fonts()
    titleFont = titleFont or love.graphics.newFont(15)
    bodyFont = bodyFont or love.graphics.newFont(12)
    smallFont = smallFont or love.graphics.newFont(11)
    return titleFont, bodyFont, smallFont
end

-- Display metadata per arena tile type (models/arena.lua TILE_PROPS keys). `name` is the
-- human-readable terrain name; `desc` is a short flavour/mechanics line.
local TILE_INFO = {
    ground   = { name = "Open Ground", desc = "Flat, open field. No movement penalty." },
    forest   = { name = "Forest",      desc = "Slow to cross. Soft cover that hampers line of sight." },
    mountain = { name = "High Ground", desc = "Steep and slow, but grants extra reach and blocks the view behind it." },
    rough    = { name = "Rough Terrain", desc = "Broken ground that slows movement." },
    obstacle = { name = "Obstacle",    desc = "Solid terrain. Blocks movement and line of sight." },
    water    = { name = "Shallow Water", desc = "Wadeable but slow. Conducts lightning: a bolt striking beside it arcs in." },
}

-- Accent per terrain type (title + border tint).
local TILE_COLOR = {
    ground   = { 0.80, 0.78, 0.62 },
    forest   = { 0.55, 0.80, 0.55 },
    mountain = { 0.72, 0.74, 0.82 },
    rough    = { 0.80, 0.66, 0.45 },
    obstacle = { 0.62, 0.62, 0.68 },
    water    = { 0.45, 0.68, 0.95 },
}
local DEFAULT_COLOR = { 0.86, 0.87, 0.92 }

local PARTY_COLOR = Colors.PARTY
local ENEMY_COLOR = Colors.ENEMY

local MUTED = { 0.62, 0.65, 0.72 }
local VALUE = { 0.90, 0.91, 0.95 }
local DESC = { 0.80, 0.82, 0.88 }

local GLYPH_GAP = 4 -- between a row's glyph and the value it marks (matches ui/item_tooltip.lua)
local BAR_GLYPH_W = 7 -- the resource mark ahead of a pool bar's HP/MP/SP tag

-- Resource pools shown as labeled bars, in draw order. Health has no fixed colour: it's filled with
-- the unit's SIDE colour (blue ally / red foe) like the board token's bar and the turn card's, so
-- the same unit reads the same way wherever it's shown. Resolved per unit in appendUnit.
local RESOURCES = {
    { stat = "health",  label = "HP" },
    { stat = "mana",    label = "MP", color = Colors.MANA },
    { stat = "stamina", label = "SP", color = Colors.STAMINA },
}

-- Flat combat stats shown as label/value rows, in draw order.
local STAT_ROWS = {
    { stat = "damage",       label = "Damage" },
    { stat = "magicDamage",  label = "Magic Dmg" },
    { stat = "defense",      label = "Defense" },
    { stat = "magicDefense", label = "Magic Def" },
    { stat = "movement",     label = "Movement" },
    { stat = "speed",        label = "Speed" },
}

local function titleCase(s)
    return (tostring(s):gsub("^%l", string.upper))
end

-- Round a status duration to 1 decimal, dropping a trailing ".0" so whole turns read as "3"
-- (matches ui/status_tooltip.lua).
local function fmtDuration(n)
    local rounded = math.floor((tonumber(n) or 0) * 10 + 0.5) / 10
    return (rounded % 1 == 0) and tostring(math.floor(rounded)) or string.format("%.1f", rounded)
end

-- Describe a sight cost (how much a tile obstructs a shot passing through it) in words.
local function coverText(sightCost)
    sightCost = sightCost or 0
    if sightCost == math.huge then return "Blocks sight" end
    if sightCost >= 2 then return "Blocks sight" end
    if sightCost == 1 then return "Soft cover" end
    return "Clear"
end

-- The accent (title/border) colour for the hovered tile: the occupant drives it when present
-- (it's the priority), else the terrain type.
local function accentFor(info)
    local unit = info.unit
    if unit and unit.char then
        return unit.side == "party" and PARTY_COLOR or ENEMY_COLOR
    end
    if info.trap then
        return info.trap.side == "party" and PARTY_COLOR or ENEMY_COLOR
    end
    return TILE_COLOR[(info.cell or {}).type] or DEFAULT_COLOR
end

-- Append the terrain section (type name, flavour, movement / line-of-sight / positional
-- modifiers). `asHead` demotes the name from a top-level title to a section heading, used when a
-- unit/trap owns the title above it.
local function appendTerrain(blocks, info, asHead)
    local cell = info.cell or { type = "ground" }
    local meta = TILE_INFO[cell.type] or { name = titleCase(cell.type or "Tile"), desc = "" }
    local col = TILE_COLOR[cell.type] or DEFAULT_COLOR

    blocks[#blocks + 1] = { kind = asHead and "head" or "title", text = meta.name, color = col }
    if meta.desc and meta.desc ~= "" then
        blocks[#blocks + 1] = { kind = "desc", text = meta.desc }
    end

    if cell.walkable == false then
        blocks[#blocks + 1] = { kind = "stat", label = "Movement", value = "Impassable",
            valueColor = ENEMY_COLOR }
    else
        local mc = cell.moveCost or 1
        blocks[#blocks + 1] = { kind = "stat", label = "Move cost", value = tostring(mc),
            valueColor = mc > 1 and { 0.92, 0.72, 0.42 } or VALUE }
    end
    blocks[#blocks + 1] = { kind = "stat", label = "Line of sight", value = coverText(cell.sightCost) }

    -- Positional bonuses granted for standing here (terrain + any field object), aggregated by
    -- combat into a flat bag, e.g. { range = 1 }.
    for _, stat in ipairs({ "range", "damage", "magicDamage", "defense", "magicDefense", "movement" }) do
        local amount = info.bonus and info.bonus[stat]
        if amount and amount ~= 0 then
            -- Reach from a vantage is a SIGHTLINE, so it lengthens shots and nothing else (see
            -- Combat.fieldRangeBonus). Say so on the tile, or a melee player reads "+1 Range" as a
            -- promise the swing won't keep.
            local label = stat == "range" and "Range bonus (ranged)" or (titleCase(stat) .. " bonus")
            blocks[#blocks + 1] = { kind = "stat", label = label,
                value = (amount > 0 and "+" or "") .. tostring(amount),
                valueColor = amount > 0 and { 0.55, 0.85, 0.55 } or ENEMY_COLOR }
        end
    end
end

-- Append a unit occupant's readout: name (as the title), side, resource pools, and combat stats.
-- `preview` (optional, a Combat.previewAbility entry for this unit) makes the HP bar show the
-- damage/heal an aimed ability would do: a red "to be lost" segment (or green "to be gained"), with
-- the numeric label reading "cur -> after / max".
local function appendUnit(blocks, unit, preview)
    local char = unit.char
    local sideCol = unit.side == "party" and PARTY_COLOR or ENEMY_COLOR
    blocks[#blocks + 1] = { kind = "title", text = (char.name or "Unit"), color = sideCol }
    blocks[#blocks + 1] = { kind = "stat", label = "Side",
        value = unit.side == "party" and "Ally" or "Enemy", valueColor = sideCol }

    -- Net change to the health pool the aimed ability would cause (damage negative, heal positive).
    local hpDelta = 0
    if preview then hpDelta = (preview.heal or 0) - (preview.damage or 0) end

    for _, r in ipairs(RESOURCES) do
        local res = char.stats and char.stats[r.stat]
        -- Only pools the unit actually has (max > 0); a beast with no mana skips the MP bar.
        if type(res) == "table" and (res.max or 0) > 0 then
            -- A reservation (sustaining a summon) lowers the ceiling `current` can reach without
            -- touching `max`, so the bar reads against the ceiling while still drawing the locked
            -- slice at its far end -- the pool you have, and the pool you've committed.
            local reserved = Combat.reservedAmount(char, r.stat)
            local block = { kind = "bar", label = r.label, stat = r.stat,
                cur = res.current or 0, max = res.max - reserved, color = r.color or sideCol }
            if reserved > 0 then
                block.reserved = reserved
                block.fullMax = res.max
            end
            if r.stat == "health" and hpDelta ~= 0 then
                block.delta = hpDelta
                block.lethal = preview and preview.lethal
            end
            blocks[#blocks + 1] = block
        end
    end

    for _, row in ipairs(STAT_ROWS) do
        local base = char.stats and char.stats[row.stat]
        if type(base) == "number" then
            local bonus = (unit.bonus and unit.bonus[row.stat]) or 0
            local value = tostring(base + bonus)
            if bonus ~= 0 then value = value .. " (" .. (bonus > 0 and "+" or "") .. bonus .. ")" end
            blocks[#blocks + 1] = { kind = "stat", label = row.label, value = value }
        end
    end

    -- Active status effects: each shown as its name (in the status's colour) with the remaining
    -- duration on the right, so a stunned/rooted unit's condition reads in full here.
    local statuses = unit.statuses
    if statuses and #statuses > 0 then
        blocks[#blocks + 1] = { kind = "sep" }
        blocks[#blocks + 1] = { kind = "head", text = "Status Effects", color = { 0.85, 0.86, 0.92 } }
        for _, st in ipairs(statuses) do
            local def = st.def or {}
            blocks[#blocks + 1] = { kind = "status",
                name = def.name or st.name or "Status",
                color = def.color or { 0.82, 0.82, 0.88 },
                -- A self-expiring status (Defending, Channeling) carries a meaningless countdown and
                -- opts out of it, exactly as in ui/status_tooltip.lua -- the same status must not
                -- quote a duration in one tooltip and withhold it in the other.
                remaining = not def.hideDuration and st.remaining or nil }
        end
    end
end

-- Disposition -> badge tint for a hazard heading (no `color` on the hazard def itself).
local HAZARD_COLOR = {
    hostile  = { 0.95, 0.55, 0.35 }, -- fire orange
    friendly = { 0.45, 0.85, 0.55 }, -- sanctuary green
    neutral  = { 0.55, 0.72, 0.95 }, -- rain blue
}

-- Append the hazards on the tile (info.hazards): a heading then, per hazard, its name (tinted by
-- disposition) with the remaining duration on the right, and a flavour line. Ordered to sit ABOVE
-- the terrain section but BELOW any occupant, so a fire/sanctuary reads between the two.
-- Returns true if it appended a hazard section (so the empty-tile caller knows to add a divider
-- before the terrain that follows). A leading divider is added only when the box already has content
-- above (an occupant); on an empty tile the hazard leads, so no leading divider.
local function appendHazard(blocks, info)
    local hazards = info.hazards
    if not hazards or #hazards == 0 then return false end
    if #blocks > 0 then blocks[#blocks + 1] = { kind = "sep" } end
    blocks[#blocks + 1] = { kind = "head", text = #hazards > 1 and "Hazards" or "Hazard",
        color = { 0.85, 0.86, 0.92 } }
    for _, h in ipairs(hazards) do
        local def = h.def or {}
        blocks[#blocks + 1] = { kind = "status",
            name = def.name or h.name or "Hazard",
            color = HAZARD_COLOR[def.disposition] or HAZARD_COLOR.neutral,
            remaining = h.remaining }
        if def.description and def.description ~= "" then
            blocks[#blocks + 1] = { kind = "desc", text = def.description }
        end
    end
    return true
end

-- Build the ordered content blocks for the hovered tile. The occupant is the priority: when a
-- unit or trap stands on the tile it leads (its name is the title, its stats first), and the
-- terrain is demoted to a section below. An empty tile shows the terrain alone. Block kinds:
--   title { text, color }              -- headline (occupant name, or terrain when empty)
--   desc  { text }                     -- terrain flavour/mechanics
--   sep   {}                           -- divider + gap
--   head  { text, color }              -- section heading (demoted terrain name)
--   stat  { label, value, valueColor } -- label (left) + value (right)
--   bar   { label, cur, max, color }   -- resource pool bar
local function buildBlocks(info)
    local blocks = {}
    local unit = info.unit
    if unit and unit.char then
        appendUnit(blocks, unit, info.preview)
        -- Terrain is only appended for a battlefield tile hover (info.cell present); a turn-order
        -- strip hover passes just the unit, so it shows the character alone. Hazards read between the
        -- occupant and the terrain.
        if info.cell then
            appendHazard(blocks, info)
            blocks[#blocks + 1] = { kind = "sep" }
            appendTerrain(blocks, info, true)
        end
    elseif info.trap then
        local trap = info.trap
        local sideCol = trap.side == "party" and PARTY_COLOR or ENEMY_COLOR
        blocks[#blocks + 1] = { kind = "title", text = (trap.name or "Trap"), color = sideCol }
        blocks[#blocks + 1] = { kind = "stat", label = "Owner",
            value = trap.side == "party" and "Ally" or "Enemy", valueColor = sideCol }
        if trap.health and trap.maxHealth then
            -- Side-coloured like a unit's HP bar: same rule everywhere, and it keeps the bar clear of
            -- the amber slice a pending strike paints on it.
            local block = { kind = "bar", label = "HP", stat = "health", cur = trap.health,
                max = trap.maxHealth, color = sideCol }
            -- A pending trap strike previews the HP it would knock off (info.preview.damage).
            if info.preview and (info.preview.damage or 0) > 0 then
                block.delta = -info.preview.damage
                block.lethal = info.preview.lethal
            end
            blocks[#blocks + 1] = block
        end
        -- What crossing this trap does: its blueprint flavour, then the raw damage / status a victim
        -- eats (dry-run via Trap.preview) -- so a revealed trap reads as a threat, not just an HP bar.
        local tdef = trap.def or {}
        if tdef.description and tdef.description ~= "" then
            blocks[#blocks + 1] = { kind = "desc", text = tdef.description }
        end
        local tp = trap.id and Trap.preview(trap.id, trap.amount)
        if tp and tp.damage > 0 then
            blocks[#blocks + 1] = { kind = "stat", label = "Damage", value = tostring(tp.damage) }
        end
        for _, st in ipairs(tp and tp.statuses or {}) do
            local def = st.def or {}
            blocks[#blocks + 1] = { kind = "stat", label = "Applies",
                value = def.name or st.id or "status", valueColor = def.color or VALUE }
        end
        if info.cell then
            appendHazard(blocks, info)
            blocks[#blocks + 1] = { kind = "sep" }
            appendTerrain(blocks, info, true)
        end
    else
        if appendHazard(blocks, info) then blocks[#blocks + 1] = { kind = "sep" } end
        appendTerrain(blocks, info, false)
    end
    return blocks
end

-- Sum the height of `blocks` at `innerW`, caching each wrapped desc's line count on the block itself
-- so the draw pass lays it out exactly as measured (the box height can never drift from its content).
local function measureBlocks(blocks, innerW, body)
    local titleH, bodyH, barH = titleFont:getHeight(), body:getHeight(), 6
    local h = 9 -- top pad
    for _, b in ipairs(blocks) do
        if b.kind == "title" then h = h + titleH + 3
        elseif b.kind == "desc" then
            local _, lines = body:getWrap(b.text, innerW)
            b.lines = math.max(1, #lines)
            h = h + b.lines * bodyH + 2
        elseif b.kind == "sep" then h = h + 8
        elseif b.kind == "head" then h = h + bodyH + 3
        elseif b.kind == "bar" then h = h + bodyH + barH + 4
        else h = h + bodyH + 1 end -- stat
    end
    return h + 9 -- bottom pad
end

-- The height the box for `info` would need at `width`. Shares buildBlocks + the measure walk with
-- draw, so it can't disagree with what gets drawn. Lets a caller stacking several boxes into a fixed
-- column work out what fits BEFORE it commits any of them to the screen (states/battle.lua).
function TileTooltip.measure(info, width)
    if not info or not (info.cell or (info.unit and info.unit.char) or info.trap) then return 0 end
    local _, body = fonts()
    return measureBlocks(buildBlocks(info), ((width or 210) - 9 * 2), body)
end

-- Draw the tooltip for the hovered tile `info` anchored near (mx, my). `maxRight` caps the box's
-- right edge so it never slides under the combat panel (defaults to the screen width). When
-- `opts.dock` is set the box is parked in the bottom-left gutter instead of following the cursor,
-- so it never covers the board highlights (the blast footprint) the player is reading. No-op when
-- there is no tile to describe.
function TileTooltip.draw(info, mx, my, maxRight, opts)
    if not info or not (info.cell or (info.unit and info.unit.char) or info.trap) then return end
    local title, body, small = fonts()
    local pad, w = 9, (opts and opts.width) or 210
    local innerW = w - pad * 2
    maxRight = maxRight or Scale.WIDTH

    local blocks = buildBlocks(info)
    local titleH, bodyH = title:getHeight(), body:getHeight()
    local barH = 6 -- pool bar thickness
    local h = measureBlocks(blocks, innerW, body)

    -- Position near the cursor; flip left and clamp so the box stays within [4, maxRight].
    local bx = mx + 14
    local maxX = maxRight - w - 4
    if bx > maxX then bx = mx - w - 14 end
    bx = math.max(4, math.min(bx, maxX))
    local by = math.max(4, math.min(my + 16, Scale.HEIGHT - h - 4))

    -- Docked mode parks the box at a fixed spot (bottom-aligned) instead of following the cursor, so
    -- it never sits over the board highlights the player is reading. `opts.dockX` sets the left edge
    -- (the caller places it inside the left column); `opts.dockBottom` is the Y the box bottom aligns
    -- to (defaults to the screen bottom) so the caller can stack several docked boxes; `opts.dockTop`
    -- floors the top so a tall box can't ride up over the buttons above it.
    if opts and opts.dock then
        bx = opts.dockX or 8
        local bottomY = opts.dockBottom or (Scale.HEIGHT - 8)
        by = math.max(opts.dockTop or 4, bottomY - h)
    end

    local accent = accentFor(info)
    love.graphics.setColor(0.08, 0.09, 0.12, 0.96)
    love.graphics.rectangle("fill", bx, by, w, h, 6, 6)
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.9)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", bx, by, w, h, 6, 6)

    local ty = by + pad
    for _, b in ipairs(blocks) do
        if b.kind == "title" then
            love.graphics.setFont(title)
            love.graphics.setColor(b.color[1], b.color[2], b.color[3], 1)
            love.graphics.print(b.text, bx + pad, ty)
            ty = ty + titleH + 3
        elseif b.kind == "desc" then
            love.graphics.setFont(body)
            love.graphics.setColor(DESC[1], DESC[2], DESC[3], 1)
            love.graphics.printf(b.text, bx + pad, ty, innerW, "left")
            ty = ty + b.lines * bodyH + 2
        elseif b.kind == "sep" then
            love.graphics.setColor(0.30, 0.33, 0.40, 0.8)
            love.graphics.line(bx + pad, ty + 4, bx + w - pad, ty + 4)
            ty = ty + 8
        elseif b.kind == "head" then
            love.graphics.setFont(body)
            love.graphics.setColor(b.color[1], b.color[2], b.color[3], 1)
            love.graphics.print(b.text, bx + pad, ty)
            ty = ty + bodyH + 3
        elseif b.kind == "bar" then
            love.graphics.setFont(small)
            -- The pool's own mark just after its HP/MP/SP tag -- the same heart / gem / drop the turn
            -- strip and the cost badges use, tinted like the label rather than the bar so the row
            -- reads as one caption. `b.stat` is absent only for a pool with no shape of its own.
            love.graphics.setColor(MUTED[1], MUTED[2], MUTED[3], 1)
            love.graphics.print(b.label, bx + pad, ty)
            local glyph = b.stat and Glyphs.RESOURCE[b.stat]
            if glyph then
                glyph(bx + pad + small:getWidth(b.label) + GLYPH_GAP, ty + 2,
                    BAR_GLYPH_W, bodyH - 4, MUTED[1], MUTED[2], MUTED[3], 1)
            end
            -- Value text: plain "cur / max", or "cur -> after / max" when a preview delta applies.
            -- `b.max` is the ceiling (max less anything reserved); a reservation appends its size.
            local curN = math.floor(b.cur + 0.5)
            local valueText = curN .. " / " .. b.max
            if b.delta then
                local after = math.max(0, math.min(b.max, b.cur + b.delta))
                valueText = curN .. " -> " .. math.floor(after + 0.5) .. " / " .. b.max
            end
            if b.reserved then valueText = valueText .. " (" .. b.reserved .. " res.)" end
            love.graphics.setColor(VALUE[1], VALUE[2], VALUE[3], 1)
            love.graphics.printf(valueText, bx + pad, ty, innerW, "right")
            local barY = ty + bodyH
            -- The track spans the pool's TRUE maximum, so the reserved slice occupies real width at
            -- its far end and the unreserved fill visibly shrinks by exactly what was committed.
            local scale = b.fullMax or b.max
            local ratio = (scale > 0) and math.max(0, math.min(1, b.cur / scale)) or 0
            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.rectangle("fill", bx + pad, barY, innerW, barH, 2, 2)
            if b.reserved and scale > 0 then
                -- The locked-away tail: the pool colour, dimmed and hatched by opacity alone.
                local resW = innerW * (b.reserved / scale)
                love.graphics.setColor(b.color[1] * 0.5, b.color[2] * 0.5, b.color[3] * 0.5, 0.7)
                love.graphics.rectangle("fill", bx + pad + innerW - resW, barY, resW, barH, 2, 2)
            end
            if b.delta and scale > 0 then
                -- Show the change as a second segment: the "after" fill in the pool colour, then the
                -- lost slice in amber (damage) or the gained slice in green (heal) beside it. The
                -- lost slice can't be red -- an enemy's HP bar is red, and red-on-red reads as nothing.
                local afterVal = math.max(0, math.min(b.max, b.cur + b.delta))
                local afterRatio = math.max(0, math.min(1, afterVal / scale))
                if b.delta < 0 then
                    local loseCol = b.lethal and Colors.LETHAL or Colors.PENDING
                    love.graphics.setColor(b.color[1], b.color[2], b.color[3], 0.95)
                    love.graphics.rectangle("fill", bx + pad, barY, innerW * afterRatio, barH, 2, 2)
                    love.graphics.setColor(loseCol[1], loseCol[2], loseCol[3], 0.95)
                    love.graphics.rectangle("fill", bx + pad + innerW * afterRatio, barY,
                        innerW * (ratio - afterRatio), barH, 2, 2)
                else
                    local gain = Colors.HEALING
                    love.graphics.setColor(b.color[1], b.color[2], b.color[3], 0.95)
                    love.graphics.rectangle("fill", bx + pad, barY, innerW * ratio, barH, 2, 2)
                    love.graphics.setColor(gain[1], gain[2], gain[3], 0.9)
                    love.graphics.rectangle("fill", bx + pad + innerW * ratio, barY,
                        innerW * (afterRatio - ratio), barH, 2, 2)
                end
            else
                love.graphics.setColor(b.color[1], b.color[2], b.color[3], 0.95)
                love.graphics.rectangle("fill", bx + pad, barY, innerW * ratio, barH, 2, 2)
            end
            ty = ty + bodyH + barH + 4
        elseif b.kind == "status" then -- status name (in its colour) left, remaining duration right
            love.graphics.setFont(body)
            love.graphics.setColor(b.color[1], b.color[2], b.color[3], 1)
            love.graphics.print(b.name, bx + pad, ty)
            -- The duration, under the hourglass -- the game's mark for "measured in ticks", worn by
            -- every number on that clock (speed badges, recovery, the initiative read-out). A status
            -- that opts out of its countdown (hideDuration) prints the name alone.
            if b.remaining then
                love.graphics.setColor(MUTED[1], MUTED[2], MUTED[3], 1)
                local text = fmtDuration(b.remaining)
                love.graphics.printf(text, bx + pad, ty, innerW, "right")
                local gw = 7
                local vx = bx + pad + innerW - body:getWidth(text)
                Glyphs.hourglass(vx - GLYPH_GAP - gw, ty + 2, gw, bodyH - 4, MUTED[1], MUTED[2], MUTED[3], 1)
            end
            ty = ty + bodyH + 1
        else -- stat: label left, value right
            love.graphics.setFont(body)
            love.graphics.setColor(MUTED[1], MUTED[2], MUTED[3], 1)
            love.graphics.print(b.label, bx + pad, ty)
            local vc = b.valueColor or VALUE
            love.graphics.setColor(vc[1], vc[2], vc[3], 1)
            love.graphics.printf(b.value, bx + pad, ty, innerW, "right")
            ty = ty + bodyH + 1
        end
    end

    love.graphics.setColor(1, 1, 1)
    -- Report the drawn box so the caller can anchor a companion panel (the action preview) to it.
    return { x = bx, y = by, w = w, h = h }
end

return TileTooltip
