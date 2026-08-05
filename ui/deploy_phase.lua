-- The DEPLOYMENT PHASE: the beat between the board being built and the first turn, where the player
-- stands up to Combat.MAX_FIELD of their marching company on the lit deploy zone and leaves the rest on
-- the bench. Every ordinary battle opens here; a scripted fight, a duel and a draft skip it and keep the
-- placement whoever set them up decided (states/battle.lua's `deploy = false`). See docs/deployment.md.
--
-- This replaced a persistent marching grid arranged in the hub. Placement is a decision about GROUND --
-- where the cover is, which flank is open, how far the enemy line is -- and none of that exists until
-- the board does, so it is made here, over the real board, with the enemy already standing on it.
--
-- Two surfaces, and the split is the whole design:
--
--   THE BOARD is the widget. Legal ground is lit with the same overlay a reinforcement uses later in
--     the fight (ui/battle_map.lua's drawDeployZone), so "you may come in here" is said once, in one
--     visual language, at minute zero and at minute ten alike.
--   THE COMPANY STRIP takes the COMBAT LOG's rect -- the board-width gutter directly under the tiles.
--     It is the one piece of screen that is about the fight without being on the board, the strip and
--     the log are never both wanted, and sitting there puts each portrait directly under the ground it
--     is about to be dragged onto. The host passes that rect in (battle's gutterRect) so the two can
--     never drift apart.
--
-- Drag-and-drop is the primary interaction -- card to tile deploys, tile to tile repositions, a drop on
-- an occupied tile swaps, and a drag back off the board withdraws -- with the whole of it also reachable
-- by keyboard and pad, per the project's three-input standard.

local Scale = require("scale")
local Theme = require("ui.theme")
local InputMode = require("input_mode")
local Colors = require("ui.colors")
local TileTooltip = require("ui.tile_tooltip")
local Combat = require("models.combat")
local Hazard = require("models.hazard")
local Player = require("models.player")

local DeployPhase = {}
DeployPhase.__index = DeployPhase

-- A press that never moves this far is a click, not a drag. The repo's shared threshold (the Loadout
-- grid and the old formation grid both used it), so a twitchy click means the same thing everywhere.
local DRAG_THRESHOLD = 5

local BUTTON_H = 22
local CARD_GAP = 6
-- The narrowest a company card may get before the strip pages instead of squeezing. Roughly a
-- portrait plus its health pip -- below this a card carries no information you can act on.
local MIN_CARD_W = 62

-- opts:
--   combat, map, arena  the live (unopened) battle and its board widget
--   roster              the marching company, in order
--   player              for the opening pick (Player.wasDeployed); nil in a probe/test harness
--   onCommit(chars, front, placed, auto)  what Begin means; the host rings the bell
--   gutter              { x, y, w, h } -- the strip's rect (the combat log's)
--   autoBattle          whether the fight should open handed to the AI (the host's standing preference)
--   allowAuto           false where auto-battle is forbidden (a tutorial); hides the toggle outright
function DeployPhase.new(opts)
    opts = opts or {}
    local self = setmetatable({}, DeployPhase)
    self.combat = opts.combat
    self.map = opts.map
    self.arena = opts.arena
    self.roster = opts.roster or {}
    self.player = opts.player
    self.onCommit = opts.onCommit
    self.gutter = opts.gutter or { x = 0, y = 0, w = 0, h = 0 }

    -- Whether the bell rings on a fight the player takes themselves or one handed straight to the AI.
    -- Decided HERE, on the same screen as the line, because "who plays this" is part of committing to a
    -- fight -- a player who wants a grind auto-run should never have to open the drawer on turn one to
    -- say so. Seeded from (and handed back to) the host's standing preference, so it stays a preference
    -- that carries across fights rather than a per-battle question. See states/battle.lua's autoAll.
    self.allowAuto = opts.allowAuto ~= false
    self.autoBattle = self.allowAuto and opts.autoBattle and true or false

    self.placed = {}        -- { { char, unit, x, y }, ... } in placement order
    self.held = nil         -- the member the keyboard/pad picked up
    self.drag = nil         -- the member the mouse is carrying
    self.cursor = 1         -- index into the strip while the strip has focus
    self.scroll = 0         -- first roster index shown in the strip (see cardRect)
    self.boardFocus = false -- keyboard/pad focus is on the board rather than the strip
    self.message = nil
    self.mx, self.my = 0, 0

    self.titleFont = Theme.display(16)
    self.font = Theme.body(13)

    -- Open on last battle's four, already placed. A player happy with them presses Begin; anyone else
    -- drags. Nobody is made to re-solve a decision they already made.
    self:autoFill()
    if not self.player then self:reset() end -- no player (a probe): open empty rather than guess

    return self
end

-- ---------------------------------------------------------------------------
-- Placement
-- ---------------------------------------------------------------------------

function DeployPhase:deployedAt(x, y)
    for _, p in ipairs(self.placed) do
        if p.x == x and p.y == y then return p end
    end
    return nil
end

function DeployPhase:deployedOf(char)
    for _, p in ipairs(self.placed) do
        if p.char == char then return p end
    end
    return nil
end

-- Take `char` off the board. The unit is dropped from the (unopened) combat outright -- nothing has
-- been applied to it yet, so there is nothing to unwind. See Combat.undeployUnit.
function DeployPhase:undeploy(char)
    for i, p in ipairs(self.placed) do
        if p.char == char then
            Combat.undeployUnit(self.combat, p.unit)
            table.remove(self.placed, i)
            return true
        end
    end
    return false
end

-- Stand `char` on (x, y), if the tile is in the zone and free. A member already placed elsewhere MOVES
-- (their old tile is given up first); dropping onto an occupied tile SWAPS the two, which is what makes
-- rearranging a line one drag instead of three. Sets `message` on a refusal -- a drag that does nothing
-- reads as a bug.
function DeployPhase:deployAt(char, x, y)
    if not char then return false end
    if not Combat.inDeployZone(self.combat, x, y) then
        self.message = "Deploy inside your own lines."
        return false
    end

    local occupant = self:deployedAt(x, y)
    if occupant and occupant.char == char then return true end
    local mine = self:deployedOf(char)
    if not mine and not occupant and #self.placed >= Combat.MAX_FIELD then
        self.message = "Only " .. Combat.MAX_FIELD .. " take the field. The rest wait on the bench."
        return false
    end

    -- Vacate both ends before re-placing either, so a swap never trips over its own occupied tiles.
    local mx, my
    if mine then mx, my = mine.x, mine.y end
    if occupant then self:undeploy(occupant.char) end
    if mine then self:undeploy(char) end

    -- No relicTraits here: which relics a body wears depends on where it ends up standing (a frontRow
    -- scope), so they are resolved once, at the commit, and stamped then. See states/battle.lua.
    local unit = Combat.deployUnit(self.combat, char, x, y)
    if not unit then
        self.message = "There is no room there."
        return false
    end
    self.placed[#self.placed + 1] = { char = char, unit = unit, x = x, y = y }

    -- The displaced member takes the mover's old tile when there was one (a true swap); otherwise they
    -- go back to the strip, which is the honest reading of "you put someone else there".
    if occupant and mx then
        local swapped = Combat.deployUnit(self.combat, occupant.char, mx, my)
        if swapped then
            self.placed[#self.placed + 1] = { char = occupant.char, unit = swapped, x = mx, y = my }
        end
    end
    self.message = nil
    return true
end

-- Auto-fill: put the first MAX_FIELD company members on the arena's own bound spawns -- exactly where
-- they would have stood before there was a phase to choose in. Members who fought last battle come
-- first, so a player who fields the same four is one button from ready.
function DeployPhase:autoFill()
    self:reset()
    local order = {}
    for _, char in ipairs(self.roster) do
        if Player.wasDeployed(self.player, char) then order[#order + 1] = char end
    end
    for _, char in ipairs(self.roster) do
        if not Player.wasDeployed(self.player, char) then order[#order + 1] = char end
    end

    local spawns = (self.arena and self.arena.party) or {}
    local si = 0
    for _, char in ipairs(order) do
        if #self.placed >= Combat.MAX_FIELD then break end
        si = si + 1
        local sp = spawns[si]
        if not (sp and Combat.inDeployZone(self.combat, sp.x, sp.y) and self:deployAt(char, sp.x, sp.y)) then
            -- No bound spawn left (or it is taken): take the first free tile of the zone instead.
            for _, t in ipairs(Combat.reinforceTiles(self.combat)) do
                if self:deployAt(char, t.x, t.y) then break end
            end
        end
    end
    self.message = nil
end

function DeployPhase:reset()
    for i = #self.placed, 1, -1 do self:undeploy(self.placed[i].char) end
    self.message = nil
end

-- The company members standing, in placement order.
function DeployPhase:deployedChars()
    local out = {}
    for _, p in ipairs(self.placed) do out[#out + 1] = p.char end
    return out
end

-- The line the player put FORWARD: of everyone deployed, those standing nearest the enemy. Measured off
-- the deployed bodies rather than off the zone, so it means what it says even on a board whose zone is
-- an odd shape -- the front line is whoever is actually in front. This is what a frontRow-scoped relic
-- and Rowan's Vigil resolve against (states/game.lua's resolveOpening).
function DeployPhase:frontLine()
    if #self.placed == 0 then return {} end
    local towardTop = Combat.enemyHomeEdge(self.combat) == "top"
    local best
    for _, p in ipairs(self.placed) do
        if not best or (towardTop and p.y < best) or (not towardTop and p.y > best) then best = p.y end
    end
    local out = {}
    for _, p in ipairs(self.placed) do
        if p.y == best then out[#out + 1] = p.char end
    end
    return out
end

function DeployPhase:begin()
    if #self.placed == 0 then
        self.message = "Put at least one of your company on the field."
        return false
    end
    if self.onCommit then
        self.onCommit(self:deployedChars(), self:frontLine(), self.placed, self.autoBattle)
    end
    return true
end

function DeployPhase:toggleAuto()
    if not self.allowAuto then return end
    self.autoBattle = not self.autoBattle
    -- Deliberately says nothing in the hint line: the switch reads its own state ("Auto: On") and the
    -- bell beside it reads "Begin (Auto)". A sentence there would only shout over a placement refusal,
    -- which is the one thing in that line the player cannot see any other way.
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

-- One card per company member, laid across the strip. It fits the whole company at once where it can,
-- so "who is left" is a glance rather than a count -- but the company is the whole roster and the
-- roster is unbounded, so cards stop shrinking at MIN_CARD_W and the strip scrolls instead. A card
-- narrower than that is a smear, and a smear you cannot pick out of is worse than a page you turn.
function DeployPhase:cardWidth()
    local n = math.max(1, #self.roster)
    local w = (self.gutter.w - CARD_GAP * (n - 1)) / n
    return math.max(MIN_CARD_W, w)
end

-- How many cards fit at the current width, and the largest first-index the strip may scroll to.
function DeployPhase:cardsVisible()
    local w = self:cardWidth()
    return math.max(1, math.floor((self.gutter.w + CARD_GAP) / (w + CARD_GAP)))
end

function DeployPhase:maxScroll()
    return math.max(0, #self.roster - self:cardsVisible())
end

-- Keep the strip cursor on screen. Called after any move of `self.cursor`.
function DeployPhase:scrollToCursor()
    local visible = self:cardsVisible()
    if self.scroll > self.cursor - 1 then self.scroll = self.cursor - 1
    elseif self.cursor > self.scroll + visible then self.scroll = self.cursor - visible end
    self.scroll = math.max(0, math.min(self:maxScroll(), self.scroll))
end

-- The rect of roster index `i`, or nil when it is scrolled out of the strip.
function DeployPhase:cardRect(i)
    local r = self.gutter
    local slot = i - self.scroll
    if slot < 1 or slot > self:cardsVisible() then return nil end
    local w = self:cardWidth()
    return r.x + (slot - 1) * (w + CARD_GAP), r.y + 4, w, r.h - BUTTON_H - 8
end

function DeployPhase:cardAt(px, py)
    for i = 1, #self.roster do
        local x, y, w, h = self:cardRect(i)
        if x and px >= x and px <= x + w and py >= y and py <= y + h then return i end
    end
    return nil
end

function DeployPhase:autoFillRect()
    local r = self.gutter
    return { x = r.x, y = r.y + r.h - BUTTON_H - 2, w = 70, h = BUTTON_H }
end

function DeployPhase:resetRect()
    local r = self.gutter
    return { x = r.x + 76, y = r.y + r.h - BUTTON_H - 2, w = 70, h = BUTTON_H }
end

function DeployPhase:beginRect()
    local r = self.gutter
    return { x = r.x + r.w - 130, y = r.y + r.h - BUTTON_H - 2, w = 130, h = BUTTON_H }
end

-- The auto-battle switch, paired flush to the LEFT of Begin: it is a modifier on the button beside it
-- ("begin -- like this"), not a third placement tool, so it sits with the bell and not with Auto-Fill
-- and Clear at the other end of the strip. Kept narrow because the whole row has to fit the NARROWEST
-- gutter there is -- an eight-column board is 480px, and the hint between the clusters pays for every
-- pixel a button takes.
function DeployPhase:autoRect()
    local r = self.gutter
    return { x = r.x + r.w - 220, y = r.y + r.h - BUTTON_H - 2, w = 84, h = BUTTON_H }
end

local function rectHas(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

-- A company member's board token, or a lettered box when the art is missing (models/sprite.lua hands
-- back a path string then). The same read the overworld strip and the turn cards take.
local function drawPortrait(char, x, y, size, font)
    local sprite = char and char.sprite
    if type(sprite) == "userdata" then
        love.graphics.setColor(1, 1, 1)
        local sw, sh = sprite:getDimensions()
        local scale = math.min(size / sw, size / sh)
        love.graphics.draw(sprite, x + size / 2, y + size / 2, 0, scale, scale, sw / 2, sh / 2)
    else
        love.graphics.setColor(0.30, 0.32, 0.40)
        love.graphics.rectangle("fill", x, y, size, size, 5, 5)
        love.graphics.setFont(font)
        love.graphics.setColor(0.90, 0.90, 0.95)
        love.graphics.printf(((char and char.name) or "?"):sub(1, 1), x, y + size / 2 - 10, size, "center")
    end
end

function DeployPhase:drawCard(i, char)
    local x, y, w, h = self:cardRect(i)
    if not x then return end -- scrolled out of the strip
    local placed = self:deployedOf(char)
    local held = self.held == char or (self.drag and self.drag.active and self.drag.char == char)

    love.graphics.setColor(0.11, 0.12, 0.16, 0.95)
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)
    love.graphics.setColor(placed and 0.72 or 0.34, placed and 0.60 or 0.38, placed and 0.40 or 0.48)
    love.graphics.rectangle("line", x, y, w, h, 6, 6)

    -- "This one is standing" is an amber bar across the card's top rather than a word over the
    -- portrait: at a company's worth of cards to a board's width there is no room for a caption, and
    -- the bar reads from further away than the text ever did.
    if placed then
        Theme.set(Theme.accentAmber)
        love.graphics.rectangle("fill", x + 3, y + 3, w - 6, 3, 2, 2)
    end

    if not held then
        local size = math.min(w - 10, h - 32)
        drawPortrait(char, x + (w - size) / 2, y + 10, size, self.font)
    end

    -- The ones standing read BRIGHT; the reserve reads quieter. The bar above already says which is
    -- which -- this just keeps the two groups from looking like one row of identical cards.
    love.graphics.setFont(self.font)
    love.graphics.setColor(placed and 0.95 or 0.70, placed and 0.93 or 0.72, placed and 0.98 or 0.80)
    love.graphics.printf(Theme.ellipsize(char.name or "?", self.font, w - 4), x + 2, y + h - 15, w - 4, "center")

    -- A health pip, so a wounded member is never deployed by accident.
    local hp = char.stats and char.stats.health
    if type(hp) == "table" and (hp.max or 0) > 0 then
        local frac = math.max(0, math.min(1, (hp.current or 0) / hp.max))
        love.graphics.setColor(0.10, 0.11, 0.15)
        love.graphics.rectangle("fill", x + 4, y + h - 22, w - 8, 4, 2, 2)
        love.graphics.setColor(Colors.PARTY[1], Colors.PARTY[2], Colors.PARTY[3])
        love.graphics.rectangle("fill", x + 4, y + h - 22, (w - 8) * frac, 4, 2, 2)
    end

    if not self.boardFocus and self.cursor == i then
        Theme.set(Theme.cursor)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x - 2, y - 2, w + 4, h + 4, 7, 7)
        love.graphics.setLineWidth(1)
    end
end

-- `on` marks a SWITCH that is currently thrown (the auto-battle toggle). It wears the spotlight gold
-- the rest of the UI spends on what is live, so an armed auto-battle is legible from the far side of
-- the screen -- a fight that plays itself is not a thing to discover after the bell.
function DeployPhase:drawButton(r, label, enabled, on)
    if on then love.graphics.setColor(0.26, 0.21, 0.12) -- a warm wash under the gold, against the row's cool slate
    else love.graphics.setColor(enabled and 0.20 or 0.13, enabled and 0.24 or 0.14, enabled and 0.30 or 0.18) end
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 4, 4)
    if on then Theme.set(Theme.accentAmber)
    else love.graphics.setColor(enabled and 0.72 or 0.34, enabled and 0.62 or 0.36, enabled and 0.40 or 0.44) end
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 4, 4)
    love.graphics.setFont(self.font)
    if on then Theme.set(Theme.accentAmber)
    else love.graphics.setColor(enabled and 0.95 or 0.52, enabled and 0.90 or 0.54, enabled and 0.70 or 0.58) end
    love.graphics.printf(label, r.x, r.y + 4, r.w, "center")
end

-- `bounds` is the board region (left column .. combat panel), so the title centres over the board.
function DeployPhase:draw(bounds)
    bounds = bounds or { x = 0, w = Scale.WIDTH }

    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf("Deploy your company  --  " .. #self.placed .. " / " .. Combat.MAX_FIELD
        .. " on the field", bounds.x, 64, bounds.w, "center")

    for i, char in ipairs(self.roster) do self:drawCard(i, char) end
    -- Only when the company overflows the strip: how many are off each end, tabbed over the card at
    -- that end. A count rather than an arrow, because "3 more" answers the question an arrow raises.
    -- Inside the gutter, never beside it -- the gutter is exactly the board's width and there is no
    -- promise of margin on either side of it.
    if self:maxScroll() > 0 then
        local r = self.gutter
        local after = #self.roster - self.scroll - self:cardsVisible()
        local function tab(label, x)
            local w = self.font:getWidth(label) + 8
            love.graphics.setColor(0.08, 0.09, 0.12, 0.9)
            love.graphics.rectangle("fill", x, r.y + 4, w, 16, 3, 3)
            love.graphics.setColor(0.60, 0.64, 0.75)
            love.graphics.print(label, x + 4, r.y + 5)
        end
        love.graphics.setFont(self.font)
        if self.scroll > 0 then tab("<" .. self.scroll, r.x + 2) end
        if after > 0 then
            local label = after .. ">"
            tab(label, r.x + r.w - self.font:getWidth(label) - 10)
        end
    end

    self:drawButton(self:autoFillRect(), "Auto-Fill", true)
    self:drawButton(self:resetRect(), "Clear", #self.placed > 0)
    -- The bell says which fight it is ringing for. A player who armed auto and then pressed a button
    -- reading "Begin Battle" would have been told nothing about the fight they were about to not play.
    -- Spelt out rather than ticked: the switch has to answer "played or watched?" on its own, from a
    -- glance, with no second control to compare itself against.
    if self.allowAuto then
        self:drawButton(self:autoRect(), self.autoBattle and "Auto: On" or "Auto: Off",
            true, self.autoBattle)
    end
    self:drawButton(self:beginRect(), self.autoBattle and "Begin (Auto)" or "Begin Battle",
        #self.placed > 0)

    -- One line, between the Clear and Begin buttons: either the last refusal, or how to work the phase.
    -- Ellipsized rather than wrapped -- a second line has nowhere to go in a strip this tall.
    local r = self.gutter
    love.graphics.setFont(self.font)
    local hintX = r.x + 152
    local hintW = (self.allowAuto and r.w - 380 or r.w - 290)
    local line, color = self.message, { 0.92, 0.62, 0.55 }
    if not line then
        color = { 0.55, 0.58, 0.68 }
        -- The long form on a wide board, a short one on a narrow gutter. A hint the strip cuts in half
        -- teaches nothing, so it says less rather than saying it truncated.
        local roomy = hintW >= 240
        if InputMode.isGamepad() then
            line = roomy and "D-pad: choose   A: pick up / place   Y: auto   Start: begin"
                or "A: place   Y: auto   Start: begin"
        else
            line = roomy and "Drag onto the lit ground; drag back here to withdraw"
                or "Drag onto lit tiles"
        end
    end
    love.graphics.setColor(color[1], color[2], color[3])
    love.graphics.print(Theme.ellipsize(line, self.font, hintW), hintX, r.y + r.h - BUTTON_H + 3)

    self:drawHover(bounds)

    -- The carried portrait rides the cursor above everything else.
    if self.drag and self.drag.active and self.drag.char then
        drawPortrait(self.drag.char, self.mx - 22, self.my - 22, 44, self.font)
    end
    love.graphics.setColor(1, 1, 1)
end

-- ---------------------------------------------------------------------------
-- Hover readout
-- ---------------------------------------------------------------------------

-- The board tile being READ this frame, as (x, y, anchorX, anchorY): the tile under the pointer on
-- mouse, and the board cursor's tile on keyboard/pad -- where there is no pointer, so the box is
-- anchored to the tile itself. Nil while the cursor is off the board (the strip, the buttons).
function DeployPhase:hoverCell()
    if InputMode.isMouse() then
        local cx, cy = self.map:cellAt(self.mx, self.my)
        if not cx then return nil end
        return cx, cy, self.mx, self.my
    end
    if not self.boardFocus then return nil end
    local c = self.map.cursor
    local px, py = self.map:cellToPixel(c.x, c.y)
    return c.x, c.y, px + self.map.size, py + self.map.size / 2
end

-- The tile under the cursor, read exactly as the fight reads it (ui/tile_tooltip.lua): the ground,
-- and whoever is standing on it. The enemy line is already on the board during this phase and where
-- to stand is a decision ABOUT it -- its reach, its armour, what it is carrying -- so the readout
-- that answers that question is here at minute zero rather than one turn after the bell.
--
-- DOCKED into the left column, in the two stacked boxes the fight uses (states/battle.lua's
-- drawTileTooltip): terrain at the column's foot, the occupant in its own box above it. Same place,
-- same split, before the bell and after it -- and a box parked off the board never covers the ground
-- being aimed at, which is why it can stay up through a drag.
--
-- `bounds` is the board region the phase draws its title over, so its left edge IS the column.
function DeployPhase:drawHover(bounds)
    local cx, cy, ax, ay = self:hoverCell()
    if not cx then return end
    local cell = self.arena and self.arena.tiles[cy] and self.arena.tiles[cy][cx]
    if not cell then return end

    local unit = Combat.unitAt(self.combat, cx, cy)
    local obj, kind = Combat.objectAt(self.combat, cx, cy)
    local terrainInfo = { cell = cell,
                          bonus = Combat.fieldBonus(self.combat, cx, cy),
                          hazards = Hazard.allAt(self.combat, cx, cy),
                          -- Marked objective ground, so "hold this" is read while choosing who stands on it.
                          objective = Combat.objectiveTileInfo(self.combat, cx, cy) }
    local objInfo
    if unit and unit.char then objInfo = { unit = unit }
    elseif kind == "wall" then objInfo = { wall = obj }
    elseif kind == "prop" then objInfo = { prop = obj } end

    -- The column's full width, minus the 16px margins the fight's docked boxes keep. There is no
    -- menu drawer open before the bell, so the stack may rise the whole height of the column.
    local W = math.max(180, ((bounds and bounds.x) or 0) - 32)
    local gap, dockTop = 8, 8
    local dock = { dock = true, dockX = 16, dockTop = dockTop, width = W }

    -- Terrain never yields; the OCCUPANT is the valve, exactly as in the fight -- losing it costs the
    -- player only a detail view of something already standing in front of them on the board.
    local budget = Scale.HEIGHT - 8 - dockTop
    local terrainH = TileTooltip.measure(terrainInfo, W) + gap
    local objH = objInfo and (TileTooltip.measure(objInfo, W) + gap) or 0

    local box = TileTooltip.draw(terrainInfo, ax, ay, Scale.WIDTH, dock)
    if objInfo and objH + terrainH <= budget then
        TileTooltip.draw(objInfo, ax, ay, Scale.WIDTH,
            { dock = true, dockX = 16, dockTop = dockTop, width = W,
              dockBottom = (box and box.y or Scale.HEIGHT - 8) - gap })
    end
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

function DeployPhase:mousemoved(x, y)
    self.mx, self.my = x, y
    if self.drag and not self.drag.active
        and (math.abs(x - self.drag.startX) > DRAG_THRESHOLD
            or math.abs(y - self.drag.startY) > DRAG_THRESHOLD) then
        self.drag.active = true
    end
    self.map:mousemoved(x, y)
end

function DeployPhase:mousepressed(x, y, button)
    if button ~= 1 then return end
    self.mx, self.my = x, y

    if rectHas(self:beginRect(), x, y) then self:begin() return end
    if self.allowAuto and rectHas(self:autoRect(), x, y) then self:toggleAuto() return end
    if rectHas(self:autoFillRect(), x, y) then self:autoFill() return end
    if rectHas(self:resetRect(), x, y) then self:reset() return end

    -- A member already in hand from the keyboard drops wherever the click lands.
    local cx, cy = self.map:cellAt(x, y)
    if self.held then
        if cx then self:deployAt(self.held, cx, cy) end
        self.held = nil
        return
    end

    if cx then
        local p = self:deployedAt(cx, cy)
        if p then self.drag = { char = p.char, from = "board", startX = x, startY = y, active = false } end
        return
    end
    local i = self:cardAt(x, y)
    if i then
        self.cursor, self.boardFocus = i, false
        self.drag = { char = self.roster[i], from = "strip", startX = x, startY = y, active = false }
    end
end

function DeployPhase:mousereleased(x, y, button)
    if button ~= 1 then return end
    local drag = self.drag
    self.drag = nil
    if not drag then return end

    local cx, cy = self.map:cellAt(x, y)
    if drag.active then
        if cx then
            self:deployAt(drag.char, cx, cy)
        elseif drag.from == "board" then
            -- Dragged off the board (onto the strip, or anywhere else): withdrawn back to the bench.
            self:undeploy(drag.char)
            self.message = nil
        end
        return
    end

    -- A click, not a drag. On the board it picks the standing member up; on a card it toggles: an
    -- unplaced member goes to the first free tile, a placed one comes back off.
    if drag.from == "board" then
        self.held = drag.char
    elseif self:deployedOf(drag.char) then
        self:undeploy(drag.char)
    else
        for _, t in ipairs(Combat.reinforceTiles(self.combat)) do
            if self:deployAt(drag.char, t.x, t.y) then break end
        end
    end
end

-- One navigation step across the two regions: the strip and the board. Pushing UP off the strip crosses
-- onto the board's cursor; pushing DOWN off the board's bottom row crosses back. The same one-cursor,
-- two-regions idiom the Loadout panel uses.
function DeployPhase:navigate(dx, dy)
    if self.boardFocus then
        if dy > 0 and self.map.cursor.y >= self.arena.rows then
            self.boardFocus = false
            return
        end
        self.map:moveCursor(dx, dy)
        return
    end
    if dy < 0 then self.boardFocus = true return end
    self.cursor = math.max(1, math.min(#self.roster, self.cursor + dx))
    self:scrollToCursor()
end

-- Wheel over the strip pages the company sideways. Only bound when there is something off-screen, so
-- on an ordinary company the wheel does nothing rather than jittering a strip that already fits.
function DeployPhase:wheelmoved(_, dy)
    if dy == 0 or self:maxScroll() == 0 then return end
    self.scroll = math.max(0, math.min(self:maxScroll(), self.scroll - dy))
end

function DeployPhase:confirm()
    if self.boardFocus then
        local c = self.map.cursor
        if self.held then
            self:deployAt(self.held, c.x, c.y)
            self.held = nil
        else
            local p = self:deployedAt(c.x, c.y)
            if p then self.held = p.char end
        end
        return
    end
    local char = self.roster[self.cursor]
    if not char then return end
    if self:deployedOf(char) then
        self:undeploy(char)
    else
        self.held = char
        self.boardFocus = true
    end
end

function DeployPhase:keypressed(key)
    if key == "return" or key == "kpenter" then self:begin()
    elseif key == "escape" then
        if self.held then self.held = nil else self.message = "Deploy your company, then Begin Battle." end
    elseif key == "space" then self:confirm()
    -- V, the same key that flips whole-side auto inside the fight (states/battle.lua): one binding for
    -- one idea, before the bell and after it.
    elseif key == "v" then self:toggleAuto()
    elseif key == "left" or key == "a" then self:navigate(-1, 0)
    elseif key == "right" or key == "d" then self:navigate(1, 0)
    elseif key == "up" or key == "w" then self:navigate(0, -1)
    elseif key == "down" or key == "s" then self:navigate(0, 1)
    end
end

function DeployPhase:gamepadpressed(_, button)
    if button == "start" then self:begin()
    elseif button == "b" then self.held = nil
    elseif button == "a" then self:confirm()
    -- Y, not the fight's A: here A is already "pick up / place", and placement outranks a switch.
    elseif button == "y" then self:toggleAuto()
    elseif button == "dpleft" then self:navigate(-1, 0)
    elseif button == "dpright" then self:navigate(1, 0)
    elseif button == "dpup" then self:navigate(0, -1)
    elseif button == "dpdown" then self:navigate(0, 1)
    end
end

-- A hand over anything that can be picked up or pressed: a company card, a member already standing on
-- the board, and the strip's buttons.
function DeployPhase:cursorKind(x, y)
    if self:cardAt(x, y) then return "hand" end
    if rectHas(self:beginRect(), x, y) or rectHas(self:autoFillRect(), x, y)
        or rectHas(self:resetRect(), x, y) then return "hand" end
    if self.allowAuto and rectHas(self:autoRect(), x, y) then return "hand" end
    local cx, cy = self.map:cellAt(x, y)
    if cx and (self.held or self:deployedAt(cx, cy)) then return "hand" end
    return "arrow"
end

return DeployPhase
