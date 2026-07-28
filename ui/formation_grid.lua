-- Reusable marching-grid editor: the Player.FORMATION_COLS x Player.FORMATION_ROWS block the party
-- stands in at the opening bell (row 1 is the FRONT LINE, nearest the enemy; models/arena.lua seats
-- the party into exactly this shape). It edits an EXISTING party's arrangement -- pick a member up and
-- drop them on another cell to swap -- over the shared Player.formationSlot / setFormationSlot helpers
-- (setFormationSlot does the swap; see models/player.lua). It does NOT add or remove members: that is
-- party composition, which states/party_select.lua layers on top of its own grid. This widget is the
-- rearrange-only core, used by the overworld party panel (ui/party_status.lua) so the marching line can
-- be re-set between fights.
--
-- Three inputs, one cursor: click a cell (or drag a member to another cell) with the mouse; arrows /
-- D-pad move the cursor and Space / A pick up then drop; the input handlers return true when they
-- consumed the event so a host can fall through to its own controls. Optionally draws each member's
-- HP/mana bars in-cell (showResources), so the panel reads attrition and formation in one view.
--
--   local grid = FormationGrid.new({ player = p, x = 40, y = 120, onChange = function() Player.save() end })
--   grid:draw(); grid:mousepressed(x,y,1); grid:keypressed("space")

local Player = require("models.player")
local Colors = require("ui.colors")
local Theme = require("ui.theme")

local FormationGrid = {}
FormationGrid.__index = FormationGrid

local DRAG_THRESHOLD = 5

function FormationGrid.new(opts)
    opts = opts or {}
    local self = setmetatable({}, FormationGrid)
    self.player = opts.player or Player.active
    self.party = opts.party or (self.player and self.player.party) or {}
    self.cell = opts.cell or 96
    self.gap = opts.gap or 14
    self.showResources = opts.showResources ~= false
    self.onChange = opts.onChange
    self.font = opts.font or Theme.body(15)
    self.smallFont = opts.smallFont or Theme.body(12)
    self.headFont = opts.headFont or Theme.display(22)

    local cols = Player.FORMATION_COLS
    local total = cols * self.cell + (cols - 1) * self.gap
    -- Explicit x wins; otherwise centre within centerWidth if given, else start at 0.
    self.originX = opts.x or (opts.centerWidth and (opts.centerWidth / 2 - total / 2)) or 0
    self.originY = opts.y or 0

    self.deployCol, self.deployRow = 1, 1
    self.grabbed = nil     -- member picked up by keyboard/pad
    self.drag = nil        -- { char, startX, startY, active }
    self.mx, self.my = 0, 0
    return self
end

function FormationGrid:totalWidth()
    local cols = Player.FORMATION_COLS
    return cols * self.cell + (cols - 1) * self.gap
end

function FormationGrid:totalHeight()
    local rows = Player.FORMATION_ROWS
    return rows * self.cell + (rows - 1) * self.gap
end

function FormationGrid:cellRect(col, row)
    return self.originX + (col - 1) * (self.cell + self.gap),
        self.originY + (row - 1) * (self.cell + self.gap), self.cell, self.cell
end

function FormationGrid:cellAt(x, y)
    for row = 1, Player.FORMATION_ROWS do
        for col = 1, Player.FORMATION_COLS do
            local cx, cy, cw, ch = self:cellRect(col, row)
            if x >= cx and x <= cx + cw and y >= cy and y <= cy + ch then return col, row end
        end
    end
    return nil
end

-- The deployed member on cell (col, row), or nil.
function FormationGrid:memberAt(col, row)
    for _, m in ipairs(self.party) do
        local slot = Player.formationSlot(self.player, m)
        if slot and slot.col == col and slot.row == row then return m end
    end
    return nil
end

-- Drop `char` onto (col, row) -- setFormationSlot swaps the occupant away -- and notify the host.
function FormationGrid:place(char, col, row)
    Player.setFormationSlot(self.player, char, col, row)
    if self.onChange then self.onChange() end
end

-- Pick-up/drop on the cursor cell (keyboard/pad, and the click path).
function FormationGrid:confirmAt(col, row)
    if self.grabbed then
        self:place(self.grabbed, col, row)
        self.grabbed = nil
    else
        local m = self:memberAt(col, row)
        if m then self.grabbed = m end
    end
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

local function drawPortrait(char, x, y, size, headFont)
    local sprite = char.sprite
    if type(sprite) == "userdata" then
        love.graphics.setColor(1, 1, 1)
        local sw, sh = sprite:getDimensions()
        local scale = math.min(size / sw, size / sh)
        love.graphics.draw(sprite, x + size / 2, y + size / 2, 0, scale, scale, sw / 2, sh / 2)
    else
        love.graphics.setColor(0.3, 0.32, 0.4)
        love.graphics.rectangle("fill", x, y, size, size, 6, 6)
        love.graphics.setFont(headFont)
        love.graphics.setColor(0.9, 0.9, 0.95)
        love.graphics.printf((char.name or "?"):sub(1, 1), x, y + size / 2 - 12, size, "center")
    end
end

-- One resource bar (current/max) filling left-to-right in `color`, drained toward empty.
local function resourceBar(x, y, w, h, cur, max, color)
    love.graphics.setColor(0.10, 0.11, 0.15)
    love.graphics.rectangle("fill", x, y, w, h, 2, 2)
    if max and max > 0 then
        local frac = math.max(0, math.min(1, cur / max))
        love.graphics.setColor(color[1], color[2], color[3])
        love.graphics.rectangle("fill", x, y, w * frac, h, 2, 2)
    end
end

function FormationGrid:draw()
    love.graphics.setFont(self.smallFont)
    love.graphics.setColor(0.62, 0.66, 0.76)
    love.graphics.printf("^ front line  (faces the enemy)", self.originX, self.originY - 20,
        self:totalWidth(), "center")

    for row = 1, Player.FORMATION_ROWS do
        for col = 1, Player.FORMATION_COLS do
            local cx, cy, cw, ch = self:cellRect(col, row)
            local member = self:memberAt(col, row)
            local held = member and (member == self.grabbed
                or (self.drag and self.drag.active and self.drag.char == member))

            love.graphics.setColor(0.13, 0.14, 0.19)
            love.graphics.rectangle("fill", cx, cy, cw, ch, 8, 8)
            local frame = row == 1 and { 0.72, 0.6, 0.4 } or { 0.4, 0.44, 0.56 }
            love.graphics.setColor(frame[1], frame[2], frame[3])
            love.graphics.rectangle("line", cx, cy, cw, ch, 8, 8)

            if member and not held then
                local portrait = self.showResources and (ch - 44) or (ch - 24)
                drawPortrait(member, cx + (cw - portrait) / 2, cy + 4, portrait, self.headFont)
                love.graphics.setFont(self.smallFont)
                love.graphics.setColor(0.9, 0.91, 0.96)
                if self.showResources then
                    local hp = member.stats and member.stats.health
                    local mp = member.stats and member.stats.mana
                    local bx, bw = cx + 6, cw - 12
                    local by = cy + ch - 30
                    if type(hp) == "table" then
                        resourceBar(bx, by, bw, 5, hp.current or 0, hp.max or 0, Colors.PARTY)
                    end
                    if type(mp) == "table" and (mp.max or 0) > 0 then
                        resourceBar(bx, by + 7, bw, 4, mp.current or 0, mp.max or 0, Colors.MANA)
                    end
                    love.graphics.setColor(0.9, 0.91, 0.96)
                    love.graphics.printf(member.name or "?", cx + 2, cy + ch - 17, cw - 4, "center")
                else
                    love.graphics.printf(member.name or "?", cx + 2, cy + ch - 17, cw - 4, "center")
                end
            elseif held then
                love.graphics.setFont(self.smallFont)
                love.graphics.setColor(0.55, 0.58, 0.68)
                love.graphics.printf("moving...", cx, cy + ch / 2 - 8, cw, "center")
            end

            if col == self.deployCol and row == self.deployRow then
                love.graphics.setColor(0.6, 0.75, 0.95)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", cx - 2, cy - 2, cw + 4, ch + 4, 9, 9)
                love.graphics.setLineWidth(1)
            end
        end
    end

    -- The dragged member's portrait rides the cursor above the grid.
    if self.drag and self.drag.active and self.drag.char then
        drawPortrait(self.drag.char, self.mx - 24, self.my - 24, 48, self.headFont)
    end
    love.graphics.setColor(1, 1, 1)
end

-- ---------------------------------------------------------------------------
-- Input (each returns true when it consumed the event)
-- ---------------------------------------------------------------------------

function FormationGrid:cursorKind(x, y)
    local col, row = self:cellAt(x, y)
    if col and (self.grabbed or self:memberAt(col, row)) then return "hand" end
    return "arrow"
end

function FormationGrid:mousepressed(x, y, button)
    if button ~= 1 then return false end
    self.mx, self.my = x, y
    local col, row = self:cellAt(x, y)
    if not col then return false end
    self.deployCol, self.deployRow = col, row
    if self.grabbed then self:confirmAt(col, row); return true end
    local member = self:memberAt(col, row)
    if member then
        self.drag = { char = member, startX = x, startY = y, active = false }
    end
    return true
end

function FormationGrid:mousemoved(x, y)
    self.mx, self.my = x, y
    if not self.drag then return end
    if not self.drag.active
        and (math.abs(x - self.drag.startX) > DRAG_THRESHOLD
            or math.abs(y - self.drag.startY) > DRAG_THRESHOLD) then
        self.drag.active = true
    end
end

function FormationGrid:mousereleased(x, y, button)
    if button ~= 1 or not self.drag then return false end
    local d = self.drag
    self.drag = nil
    local col, row = self:cellAt(x, y)
    if d.active then
        if col then self:place(d.char, col, row) end -- dropped off the grid: no move
        return true
    end
    -- A click that never dragged: pick up / drop on the cell.
    if col then self:confirmAt(col, row) end
    return true
end

-- Navigate within the grid. Returns false when the cursor would step off an edge in `dir`, so a host
-- can move focus elsewhere (e.g. the overworld panel's buttons) instead of the cursor sticking.
function FormationGrid:navigate(dc, dr)
    local col = self.deployCol + dc
    local row = self.deployRow + dr
    if col < 1 or col > Player.FORMATION_COLS or row < 1 or row > Player.FORMATION_ROWS then
        return false
    end
    self.deployCol, self.deployRow = col, row
    return true
end

function FormationGrid:keypressed(key)
    if key == "space" then self:confirmAt(self.deployCol, self.deployRow); return true
    elseif key == "left" or key == "a" then return self:navigate(-1, 0)
    elseif key == "right" or key == "d" then return self:navigate(1, 0)
    elseif key == "up" or key == "w" then return self:navigate(0, -1)
    elseif key == "down" or key == "s" then return self:navigate(0, 1)
    elseif key == "escape" and self.grabbed then self.grabbed = nil; return true
    end
    return false
end

function FormationGrid:gamepadpressed(_, button)
    if button == "a" then self:confirmAt(self.deployCol, self.deployRow); return true
    elseif button == "dpleft" then return self:navigate(-1, 0)
    elseif button == "dpright" then return self:navigate(1, 0)
    elseif button == "dpup" then return self:navigate(0, -1)
    elseif button == "dpdown" then return self:navigate(0, 1)
    elseif button == "b" and self.grabbed then self.grabbed = nil; return true
    end
    return false
end

return FormationGrid
