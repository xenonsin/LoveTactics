-- The DEPLOYMENT PHASE: the beat between the board being built and the first turn, where the player
-- arranges the bodies they brought on the lit deploy zone. Every ordinary battle opens here; a scripted
-- fight, a duel and a draft skip it and keep the placement whoever set them up decided
-- (states/battle.lua's `deploy = false`). See docs/deployment.md.
--
-- This replaced a persistent marching grid arranged in the hub. Placement is a decision about GROUND --
-- where the cover is, which flank is open, how far the enemy line is -- and none of that exists until
-- the board does, so it is made here, over the real board, with the enemy already standing on it.
--
-- THERE IS NO COMPANY STRIP, AND NO BENCH. It had both: a row of portrait cards in the gutter, one per
-- company member, dragged onto the board to field up to Combat.MAX_FIELD of eight. Both are gone,
-- because the pair of numbers that made them a decision stopped being two numbers. The expedition is
-- picked at the Gate and capped at Descent.PARTY_MAX; the field is capped at Combat.MAX_FIELD; both are
-- four. A strip whose every card must end up on the board is not a choice of WHO, it is a list of who
-- you already brought -- and it was charging a third of the screen for the telling. The choice of who
-- goes down is made at the Gate now, and this phase makes the only one left: WHERE each of them stands.
--
-- So there is one surface, and it is THE BOARD. Everyone is standing on it the moment the phase opens
-- (autoFill), and the whole interaction is moving them: drag a body to another lit tile, drop it on a
-- ally to swap the two. Legal ground is lit with the same overlay a reinforcement uses later in the
-- fight (ui/battle_map.lua's drawDeployZone), so "you may stand here" is said once, in one visual
-- language, at minute zero and at minute ten alike.
--
-- THE CONTROLS -- Loadout, Reset Line, Auto (with the playback-speed cycler paired to its right while
--   it is on) and the bell -- stack down the LEFT COLUMN, under the two standing plates the host keeps
--   there before the bell (Settings and the board-turn pair -- there is no hamburger on this screen),
--   in the band the fight's own entries occupy. The column is where this screen already keeps its
--   furniture, so the controls read as the screen's rather than the board's. The host passes the band
--   in (battle's deployControlRect).
-- THE HINT LINE is all that is left in the gutter, drawn along its top edge, directly under the board:
--   the last refusal, or how to work the phase. The host still passes the rect (battle's gutterRect)
--   because it is the combat log's and the two must not drift apart.
--
-- Drag-and-drop is the primary interaction -- tile to tile repositions and a drop on an occupied tile
-- swaps -- with the whole of it also reachable by keyboard and pad, per the project's three-input
-- standard. THE BOARD IS ONE CURSOR AND THE COLUMN IS THE OTHER REGION: confirm on a standing body
-- lifts it, confirm on a tile sets it down (swapping with whoever is there), and a step LEFT off the
-- board's own edge crosses into the control stack, where up/down walks the plates and a step right
-- comes back. The crossing is read off the board cursor REFUSING to move rather than off the grid
-- coordinate, so a board the player has turned still crosses on the key that points at the column.
-- Every control is on that ring, which is what makes Reset Line reachable without a pad button of its
-- own -- the stack can grow a fourth plate without going hunting for a spare face button.

local Scale = require("scale")
local Theme = require("ui.theme")
local InputMode = require("input_mode")
local TileTooltip = require("ui.tile_tooltip")
local Combat = require("models.combat")
local Hazard = require("models.hazard")
local Player = require("models.player")

local DeployPhase = {}
DeployPhase.__index = DeployPhase

-- A press that never moves this far is a click, not a drag. The repo's shared threshold (the Loadout
-- grid and the old formation grid both used it), so a twitchy click means the same thing everywhere.
local DRAG_THRESHOLD = 5

-- The hint / refusal line is drawn along the TOP of the gutter -- directly under the board, which is
-- where the eye already is. It used to sit at the foot of the strip, in a band reserved out of the
-- cards' height (HINT_H, gone with them); with the strip gone, the foot of an empty rect is the far
-- side of a gap from everything the line is about.
-- One control in the left column, sized to the plates above it (battle's deploySettingsButton)
-- so the column reads as one stack of plates rather than two kinds of button.
local CTRL_H = 36
local CTRL_GAP = 8
-- A control PAIRED to the right of the one above it, sharing its row: the playback-speed cycler beside
-- the auto switch. The fight's own speed button has exactly this shape and offset beside its Auto entry
-- (states/battle.lua's speedButton), so the pair reads the same before the bell as after it.
local PAIR_GAP = 4
local PAIR_W = 56
-- The speeds the cycler steps through when the host names none -- a probe, a test harness. A live fight
-- hands its own list in (states/battle.lua's SPEED_STEPS), so the two can never offer different gears.
local SPEED_STEPS = { 1, 2, 3 }
-- The phase's headline takes the THIRD of the fight's three HUD lines -- the row the control hint
-- occupies once the bell rings. The two above it are the host's: the banner, which reads "Deployment
-- Phase" while this is up, and the objective under it, which says the same thing before the fight as
-- during it. This line is the one about how to WORK the phase, so it goes last, directly above the
-- board. The host passes the row down (`bounds.titleY`, states/battle.lua's HUD_HINT_Y), because the
-- three rows are one column of text and a widget guessing at the third would drift off the first two.
-- The fallback is only for a probe that hands no bounds at all.
local TITLE_Y = 68

-- opts:
--   combat, map, arena  the live (unopened) battle and its board widget
--   roster              the marching company, in order
--   player              for the opening pick (Player.wasDeployed); nil in a probe/test harness
--   onCommit(chars, front, placed, auto)  what Begin means; the host rings the bell
--   gutter              { x, y, w, h } -- the strip's rect (the combat log's)
--   column              { x, y, w } -- the top of the left column's free band; the controls stack down it
--   autoBattle          whether the fight should open handed to the AI (the host's standing preference)
--   allowAuto           false where auto-battle is forbidden (a tutorial); hides the toggle outright
--   autoSpeed           the playback speed a watched fight opens at (the host's standing preference)
--   speedSteps          the gears that cycler steps through; the host's list, so the fight and the
--                       phase can never offer different ones
--   onLoadout           opens the Loadout screen over the phase; nil hides the button outright (a
--                       fight with no player behind it -- a probe, a debug board -- has no stash to
--                       open). The host owns that modal, exactly as it owns the Settings one.
function DeployPhase.new(opts)
    opts = opts or {}
    local self = setmetatable({}, DeployPhase)
    self.combat = opts.combat
    self.map = opts.map
    self.arena = opts.arena
    self.roster = opts.roster or {}
    self.player = opts.player
    self.onCommit = opts.onCommit
    self.onLoadout = opts.onLoadout
    self.gutter = opts.gutter or { x = 0, y = 0, w = 0, h = 0 }
    self.column = opts.column or { x = 16, y = 104, w = 130 }

    -- Whether the bell rings on a fight the player takes themselves or one handed straight to the AI.
    -- Decided HERE, on the same screen as the line, because "who plays this" is part of committing to a
    -- fight -- a player who wants a grind auto-run should never have to open the drawer on turn one to
    -- say so. Seeded from (and handed back to) the host's standing preference, so it stays a preference
    -- that carries across fights rather than a per-battle question. See states/battle.lua's autoAll.
    self.allowAuto = opts.allowAuto ~= false
    self.autoBattle = self.allowAuto and opts.autoBattle and true or false
    -- How fast a WATCHED fight plays, cycled beside the switch that decides it is watched at all. The
    -- same preference the fight's own cycler steps (states/battle.lua's autoSpeed), seeded here and
    -- handed back on the commit: a player who armed auto has already said they are watching this one,
    -- and the pace they want to watch it at is part of that same sentence rather than a control they
    -- have to go into the drawer for once the bell has rung.
    self.speedSteps = opts.speedSteps or SPEED_STEPS
    self.autoSpeed = opts.autoSpeed or self.speedSteps[1]

    self.placed = {}  -- { { char, unit, x, y }, ... } in placement order
    self.held = nil   -- the member the keyboard/pad picked up
    self.drag = nil   -- the member the mouse is carrying
    -- Which CONTROL the keyboard/pad selection is sitting on, by key, or nil while the selection is the
    -- board's cursor. Stored as the key rather than an index because the stack changes shape under it:
    -- the speed cycler appears and vanishes with the auto switch, and an index would quietly slide onto
    -- a different plate the frame that happened.
    self.focus = nil
    self.message = nil
    self.mx, self.my = 0, 0

    self.titleFont = Theme.display(16)
    self.font = Theme.body(13)
    -- The column's plates are lettered in the same display face as the host's entries they stack under
    -- (states/battle.lua's hudFont), so the whole column reads as one set of controls -- but sized ONCE
    -- against the longest label the stack can show, so every plate is lettered alike and the bell's two
    -- words are not the one thing that overflows its plate.
    self.buttonFont = Theme.fitText(Theme.display, "Begin Battle", self.column.w - 12, 16, 11)

    -- Everyone the player brought, standing, before the phase has drawn a frame. This is not a
    -- convenience any more, it is the phase's premise: there is no strip to drag from, so a body that
    -- opened un-placed could never be placed at all. A player happy with the arrangement presses
    -- Begin; anyone else drags. Nobody is made to re-solve a decision they already made.
    --
    -- Runs with no player behind it too (a probe, a test harness). It used to open EMPTY in that case
    -- rather than guess at who fought last -- which was the right call while a strip could correct the
    -- guess, and is a board nobody can put a body on now that one cannot.
    self:autoFill()
    -- Open the board cursor ON somebody. The map seats its own cursor at construction, on the first
    -- living party unit or the grid centre -- and before this phase nobody is standing, so it is always
    -- the centre, which on an ordinary board is a bare tile in no-man's-land. A pad or keyboard player
    -- would open the phase with the selection parked on nothing and a walk ahead of them before the
    -- first thing they can touch. The mouse never noticed because its cursor is wherever the pointer is.
    local first = self.placed[1]
    if first and self.map and self.map.cursor then
        self.map.cursor.x, self.map.cursor.y = first.x, first.y
    end

    return self
end

-- ---------------------------------------------------------------------------
-- Placement
-- ---------------------------------------------------------------------------

-- The placed member whose BODY covers (x, y) -- any cell of it, not just the anchor it was dropped on,
-- so a wide body is picked back up (and swapped with) from wherever the player clicked it.
function DeployPhase:deployedAt(x, y)
    for _, p in ipairs(self.placed) do
        local w, h = (p.unit and p.unit.w) or 1, (p.unit and p.unit.h) or 1
        if x >= p.x and x < p.x + w and y >= p.y and y < p.y + h then return p end
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
    if not mine and #self.placed >= Combat.MAX_FIELD then
        self.message = "Only " .. Combat.MAX_FIELD .. " take the field."
        return false
    end
    -- A SWAP NEEDS TWO TILES. The occupant is about to be lifted, and the only seat they can be given
    -- is the mover's own -- so a mover who is not standing anywhere would leave them holding nothing.
    -- Unreachable in a fight (everyone is placed at open) and reachable from a probe that placed
    -- nobody, which is exactly the kind of caller that used to get a body quietly deleted.
    if occupant and not mine then
        self.message = "There is nowhere to put " .. (occupant.char.name or "them") .. "."
        return false
    end

    -- Is the ground free for THIS body? Asked before anyone is lifted, so a refusal leaves the line
    -- exactly as it stood rather than taking the mover off the board on its way to a tile it cannot
    -- have. The two bodies this drag lifts do not count against it: the mover is leaving its own cells,
    -- and a swap's occupant is leaving theirs. Anybody else standing there -- an enemy whose 2x2 body
    -- reaches into the zone -- does.
    local fp = char.footprint or { w = 1, h = 1 }
    if not Combat.footprintFree(self.combat, fp.w or 1, fp.h or 1, x, y,
            mine and mine.unit, occupant and occupant.unit) then
        self.message = "There is no room there."
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

    -- The displaced member takes the mover's old tile. Always a true swap now: the guard above refuses
    -- the drop outright rather than lifting somebody with nowhere to set them down.
    if occupant and mx then
        local swapped = Combat.deployUnit(self.combat, occupant.char, mx, my)
        if swapped then
            self.placed[#self.placed + 1] = { char = occupant.char, unit = swapped, x = mx, y = my }
        end
    end
    self.message = nil
    return true
end

-- Stand the line: put the company on the arena's own bound spawns -- exactly where they would have
-- stood before there was a phase to arrange in. Members who fought last battle come first, so the
-- opening arrangement echoes the last one rather than the roster's order.
--
-- Runs at open, and again behind the Reset Line control -- which is the only way back to this
-- arrangement once the player has shuffled, and the reason that control still exists with nothing left
-- to fill from. The MAX_FIELD break is a ceiling nothing underground reaches (the expedition is capped
-- at four before it ever gets here) and is kept because it is this file's own promise, not the Gate's.
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

-- Re-read what GEAR decides for every body already standing. Called after the player has been in the
-- Loadout screen, because a deployed unit snapshots that at the moment it is stood up -- see
-- Combat.restampDeployed, which is also where the reason this re-stamps instead of re-placing lives.
-- Nobody is moved: where the company stands is the player's own answer and closing a screen is not a
-- reason to revisit it.
function DeployPhase:refreshPlacements()
    for _, p in ipairs(self.placed) do Combat.restampDeployed(self.combat, p.unit) end
    self.held, self.drag = nil, nil
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
        self.onCommit(self:deployedChars(), self:frontLine(), self.placed, self.autoBattle, self.autoSpeed)
    end
    return true
end

-- Step the playback speed on to the next gear, wrapping. A no-op unless the fight is actually being
-- handed over: the cycler is not drawn otherwise, and the key that reaches it must not quietly change a
-- setting whose control is off screen (the fight's F does the same).
function DeployPhase:cycleSpeed()
    if not (self.allowAuto and self.autoBattle) then return end
    local steps = self.speedSteps
    local i = 1
    for n, v in ipairs(steps) do if v == self.autoSpeed then i = n break end end
    self.autoSpeed = steps[i % #steps + 1]
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

-- THE CARD LAYOUT STOOD HERE -- cardsVisible, cardWidth, maxScroll, scrollToCursor, cardRect, cardAt.
-- Six functions and two pieces of state (`scroll`, `cursor`) whose whole job was to divide the gutter
-- into a row of portraits and page it when the company overflowed. Nothing pages now, because nothing
-- is listed: the company IS the four on the board. See the header.

-- The control stack, top to bottom, as { key, rect, label, enabled, on }. Built from ONE list so the
-- draw, the hit-test and the hand cursor can never disagree about what is showing or where -- a button
-- that is hidden here is hidden everywhere, which is what keeps a fight with no stash behind it from
-- having an invisible Loadout you can still click.
--
-- The order is the order the decisions are made in: kit the company, put the line back, say who plays
-- -- and the bell last, because it is the one that ends the phase.
function DeployPhase:controls()
    local out, row = {}, 0
    local function add(key, label, enabled, on)
        row = row + 1
        out[#out + 1] = { key = key, label = label, enabled = enabled ~= false, on = on,
                   rect = { x = self.column.x, y = self.column.y + (row - 1) * (CTRL_H + CTRL_GAP),
                            w = self.column.w, h = CTRL_H } }
    end
    -- A control that shares the row above it, flush to its right: it is a setting ON that control, not
    -- a step after it, and a stack that spent a whole row on it would say otherwise.
    local function addBeside(key, label, enabled, on)
        local prev = out[#out].rect
        out[#out + 1] = { key = key, label = label, enabled = enabled ~= false, on = on,
                          rect = { x = prev.x + prev.w + PAIR_GAP, y = prev.y, w = PAIR_W, h = CTRL_H } }
    end
    if self.onLoadout then add("loadout", "Loadout") end
    -- "Reset Line", not the "Auto-Fill" it was: there is nothing left to fill FROM, and what the button
    -- now does is put a shuffled line back the way the phase opened it. Its neighbour "Clear" went with
    -- the strip -- a board the player could empty with no card to refill it from is a phase you can
    -- lock yourself out of, and an empty field is not an arrangement anybody wants to reach in one
    -- press. The way out of a bad line is Reset, not a blank board.
    add("autofill", "Reset Line")
    -- The auto-battle switch sits directly above the bell: it is a modifier on the button below it
    -- ("begin -- like this"), not a third placement tool. Spelt out rather than ticked -- it has to
    -- answer "played or watched?" on its own, from a glance, with no second control to compare against.
    if self.allowAuto then add("auto", self.autoBattle and "Auto: On" or "Auto: Off", true, self.autoBattle) end
    -- Playback speed, paired to the switch's right and drawn only while it is thrown -- exactly where
    -- and when the fight draws its own (states/battle.lua's speedButton). How fast the AI plays is
    -- meaningless in a fight the player is taking themselves, and a plate that answered nothing would
    -- still be a plate the eye has to rule out.
    if self.allowAuto and self.autoBattle then
        addBeside("speed", tostring(self.autoSpeed) .. "x", true, true)
    end
    -- The bell says which fight it is ringing for. A player who armed auto and then pressed a button
    -- reading "Begin Battle" would have been told nothing about the fight they were about to not play.
    add("begin", self.autoBattle and "Begin (Auto)" or "Begin Battle", #self.placed > 0)
    return out
end

local function rectHas(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

-- The control under (x, y), or nil. Only ENABLED ones answer: a Clear with nothing to clear is not a
-- button that does nothing, it is not a button.
function DeployPhase:controlAt(x, y)
    for _, c in ipairs(self:controls()) do
        if c.enabled and rectHas(c.rect, x, y) then return c.key end
    end
    return nil
end

-- What each control means, in one place, so a click and a key press cannot drift apart.
function DeployPhase:press(key)
    if key == "loadout" then if self.onLoadout then self.onLoadout() end
    elseif key == "autofill" then self:autoFill()
    elseif key == "auto" then self:toggleAuto()
    elseif key == "speed" then self:cycleSpeed()
    elseif key == "begin" then self:begin() end
end

-- The stack as ROWS, top to bottom, each row left to right: the plates that share a y (the auto switch
-- and the speed cycler paired to its right) are one row. The keyboard/pad selection walks rows with
-- up/down and a row's own plates with left/right, so the arrow the player presses points at the plate
-- they get -- which a flat list could not do, since the speed cycler comes after Auto in the list and
-- sits beside it on the screen.
function DeployPhase:controlRows()
    local rows = {}
    for _, c in ipairs(self:controls()) do
        local row = rows[#rows]
        if row and row[1].rect.y == c.rect.y then row[#row + 1] = c else rows[#rows + 1] = { c } end
    end
    return rows
end

-- The focused control, and where it sits, as (control, rowIndex, colIndex). Self-healing: a focus key
-- whose plate has gone (the speed cycler, when V throws the auto switch off while the selection is on
-- it) falls back to the first plate of the row it shared rather than dumping the player back onto the
-- board -- the selection should never vanish because a control did.
function DeployPhase:focused()
    if not self.focus then return nil end
    local rows = self:controlRows()
    for ri, row in ipairs(rows) do
        for ci, c in ipairs(row) do
            if c.key == self.focus then return c, ri, ci end
        end
    end
    local fallback = rows[#rows] and rows[#rows][1]
    -- The cycler's row is Auto's; anything else that disappears falls to the foot of the stack, which
    -- is the bell -- the one plate that is always there.
    for _, row in ipairs(rows) do
        if row[1].key == "auto" then fallback = row[1] break end
    end
    self.focus = fallback and fallback.key or nil
    return self:focused()
end

-- Cross from the board into the stack, landing on the plate the cursor was already looking across at:
-- the row whose middle is nearest the cursor's own height on screen. A crossing that always landed on
-- the top plate would make the column feel like a menu the board throws you into rather than the thing
-- standing beside the tile you were on.
function DeployPhase:enterColumn()
    local rows = self:controlRows()
    if #rows == 0 then return end
    local cy = self.column.y
    if self.map and self.map.cursor and self.map.cellToPixel then
        local _, py = self.map:cellToPixel(self.map.cursor.x, self.map.cursor.y)
        cy = py + (self.map.size or 0) / 2
    end
    local best, bestD = rows[1][1], math.huge
    for _, row in ipairs(rows) do
        local r = row[1].rect
        local d = math.abs(r.y + r.h / 2 - cy)
        if d < bestD then best, bestD = row[1], d end
    end
    self.focus = best.key
end

-- One navigation step INSIDE the stack. A step right off the last plate of a row leaves the column and
-- gives the board its cursor back -- the same edge, crossed the other way.
function DeployPhase:navigateColumn(dx, dy)
    local _, ri, ci = self:focused()
    if not ri then return end
    local rows = self:controlRows()
    if dy ~= 0 then
        ri = math.max(1, math.min(#rows, ri + dy))
        ci = math.min(ci, #rows[ri])
    elseif dx > 0 then
        if ci >= #rows[ri] then self.focus = nil return end
        ci = ci + 1
    elseif dx < 0 then
        ci = math.max(1, ci - 1)
    end
    self.focus = rows[ri][ci].key
end

-- The foot of the control stack: what the docked hover boxes below may rise to. The column is shared,
-- and a tooltip that grew up over the bell would cover the one control the phase cannot do without.
-- The LOWEST plate rather than the last one in the list, since a paired control (the speed cycler)
-- shares a row with the entry before it and so is not the stack's foot however late it is added.
function DeployPhase:controlsBottom()
    local bottom = self.column.y
    for _, c in ipairs(self:controls()) do bottom = math.max(bottom, c.rect.y + c.rect.h) end
    return bottom
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


-- One control plate, in the left column's own look (states/battle.lua's drawMenuEntry): a slate face
-- with a quiet bronze frame and bone label, greyed when the control cannot be pressed. `on` marks a
-- SWITCH that is currently thrown (the auto-battle toggle); it wears the spotlight gold the rest of the
-- UI spends on what is live, so an armed auto-battle is legible from the far side of the screen -- a
-- fight that plays itself is not a thing to discover after the bell.
-- `focus` marks the plate the keyboard/pad selection is SITTING on -- the cool steel the rest of the UI
-- spends on a selection that moves, kept clear of the gold a thrown switch wears, so a focused Auto
-- reads as both at once (a steel ring around a gold plate) rather than one shouting over the other.
function DeployPhase:drawButton(r, label, enabled, on, focus)
    Theme.set(on and Theme.panel or Theme.panel2, enabled and 1 or 0.7)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, Theme.R, Theme.R)
    love.graphics.setLineWidth(on and 1.5 or 1)
    if on then Theme.set(Theme.accentAmber) else Theme.set(Theme.frame, enabled and 1 or 0.5) end
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, Theme.R, Theme.R)
    if focus then
        Theme.set(Theme.cursor)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", r.x - 2.5, r.y - 2.5, r.w + 5, r.h + 5, Theme.R + 2, Theme.R + 2)
    end
    love.graphics.setLineWidth(1)
    love.graphics.setFont(self.buttonFont)
    if on then Theme.set(Theme.accentAmber)
    elseif enabled then Theme.set(Theme.ink)
    else Theme.set(Theme.muted, 0.6) end
    love.graphics.printf(label, r.x, r.y + r.h / 2 - self.buttonFont:getHeight() / 2, r.w, "center")
end

-- `bounds` is the board region (left column .. combat panel), so the title centres over the board.
-- `bounds.dockTop` is the y the docked hover boxes may rise to (the host's own plates sit above it).
function DeployPhase:draw(bounds)
    bounds = bounds or { x = 0, w = Scale.WIDTH }

    -- No "N / 4 on the field" any more. That count was the strip's readout -- it moved while cards came
    -- on and off, and it was the only place the bench was legible. Everyone stands from the first frame
    -- now, so it could only ever read "4 / 4", and a figure no decision turns on is a figure to cut.
    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf("Set your line", bounds.x, bounds.titleY or TITLE_Y, bounds.w, "center")

    -- The selection ring is drawn only while the player is actually steering with it. On the mouse the
    -- pointer says where the press will land, and a second, stale marker parked on a plate nobody is
    -- looking at would be a lie about what Space does next.
    local focusKey = (not InputMode.isMouse()) and self.focus or nil
    for _, c in ipairs(self:controls()) do
        self:drawButton(c.rect, c.label, c.enabled, c.on, c.key == focusKey)
    end

    -- One line along the TOP of the gutter, board-width: either the last refusal, or how to work the
    -- phase. It sat at the foot of the strip while there was a strip under it to belong to; now the
    -- gutter is empty and the line goes where it is read -- against the board, under the tiles the
    -- refusal is about. Ellipsized rather than wrapped -- a second line teaches nothing a first cannot.
    local r = self.gutter
    love.graphics.setFont(self.font)
    local hintX = r.x + 2
    local hintW = r.w - 4
    local line, color = self.message, { 0.92, 0.62, 0.55 }
    if not line then
        color = { 0.55, 0.58, 0.68 }
        -- The long form on a wide board, a short one on a narrow gutter. A hint the board cuts in half
        -- teaches nothing, so it says less rather than saying it truncated.
        local roomy = hintW >= 240
        local pad = InputMode.isGamepad()
        if self.focus and not InputMode.isMouse() then
            -- The selection has left the board for the column. What the confirm key does changed with
            -- it, and so does the way back -- neither of which the board's own line says.
            line = pad and "A: press   Right: back to the board   B: cancel"
                or "Space: press   Right: back to the board"
        elseif self.held then
            -- A body is IN HAND. The line stops teaching the phase and answers the only question the
            -- player has while carrying one: where can I put them down, and what happens if somebody
            -- is already there.
            if pad then
                line = roomy and "D-pad: choose a lit tile   A: set down (on an ally to trade places)   B: cancel"
                    or "A: set down   B: cancel"
            elseif InputMode.isMouse() then
                line = roomy and "Click a lit tile to set them down; on an ally to trade places"
                    or "Click a lit tile"
            else
                line = roomy and "Arrows: choose a lit tile   Space: set down (on an ally to trade places)   Esc: cancel"
                    or "Space: set down   Esc: cancel"
            end
        elseif pad then
            line = roomy and ("D-pad: move cursor   A: pick up / drop   "
                    .. (self.onLoadout and "X: loadout   " or "") .. "Y: auto   Start: begin")
                or "A: pick up / drop   Y: auto   Start: begin"
        elseif InputMode.isMouse() then
            -- Says the swap outright. It is the whole of the phase on a board where everyone is already
            -- standing -- a player who does not know a drop on an ally trades their places has no
            -- move but shuffling into the gaps.
            line = roomy and "Drag a body to another lit tile; drop on an ally to trade places"
                or "Drag between lit tiles"
        else
            -- THE KEYBOARD USED TO BE TOLD TO DRAG. It fell through to the mouse's line -- and it is the
            -- mode the game BOOTS in (input_mode.lua's default), so a player who had not yet touched
            -- anything was taught the one verb they did not have. It gets its own keys, and the step
            -- into the column, which is the only thing on this screen a key alone would not find.
            line = roomy and "Arrows: move cursor   Space: pick up / drop   Left: controls   Enter: begin"
                or "Space: pick up / drop   Enter: begin"
        end
    end
    love.graphics.setColor(color[1], color[2], color[3])
    love.graphics.print(Theme.ellipsize(line, self.font, hintW), hintX, r.y + 3)

    self:drawHover(bounds)
    self:drawHeld()

    -- The carried portrait rides the cursor above everything else.
    if self.drag and self.drag.active and self.drag.char then
        drawPortrait(self.drag.char, self.mx - 22, self.my - 22, 44, self.font)
    end
    love.graphics.setColor(1, 1, 1)
end

-- One tile of the board, ringed. Drawn per CELL rather than as one rect over a body's footprint,
-- because a turned board puts a wide body's anchor somewhere other than the top-left of its own block.
local function ringCell(map, x, y, color, alpha)
    local px, py = map:cellToPixel(x, y)
    local s = map.size
    Theme.set(color, alpha or 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", px + 2, py + 2, s - 4, s - 4, 4, 4)
    love.graphics.setLineWidth(1)
end

-- THE BODY IN HAND. `held` is the pick-up-then-put-down half of the placement -- the whole of it on a
-- keyboard or a pad, and what a plain click (a press that never became a drag) leaves behind on the
-- mouse -- and it drew NOTHING. A player pressed A on their knight, the screen did not move, and the
-- next press dropped them somewhere: the phase's primary verb was invisible on two of its three inputs.
--
-- So it says three things, in the order they are asked: WHO is lifted (their own tile ringed, which
-- survives the cursor walking away from it), WHERE they would land (their portrait riding the board
-- cursor, exactly as the drag's rides the pointer), and WHO ELSE it would move -- an ally under the
-- cursor is ringed in the same gold, because the two are about to trade and a swap that only lit one
-- of its two tiles would read as an overwrite.
function DeployPhase:drawHeld()
    local p = self.held and self:deployedOf(self.held)
    if not p or not self.map then return end

    local w, h = (p.unit and p.unit.w) or 1, (p.unit and p.unit.h) or 1
    for dy = 0, h - 1 do
        for dx = 0, w - 1 do ringCell(self.map, p.x + dx, p.y + dy, Theme.accentAmber, 0.9) end
    end

    local mouse = InputMode.isMouse()
    local px, py = self.mx, self.my
    if not mouse then
        local c = self.map.cursor
        -- The occupant of the tile the selection is over: the other half of the trade, lit as such.
        local under = self:deployedAt(c.x, c.y)
        if under and under.char ~= self.held then
            local uw, uh = (under.unit and under.unit.w) or 1, (under.unit and under.unit.h) or 1
            for dy = 0, uh - 1 do
                for dx = 0, uw - 1 do ringCell(self.map, under.x + dx, under.y + dy, Theme.accentAmber, 0.55) end
            end
        end
        local cx, cy = self.map:cellToPixel(c.x, c.y)
        px, py = cx + self.map.size / 2, cy + self.map.size / 2
    end
    drawPortrait(self.held, px - 22, py - 22, 44, self.font)
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

    -- The column's full width, minus the 16px margins the fight's docked boxes keep. The stack rises to
    -- the host's ceiling (`dockTop`) -- under the Settings and board-turn plates it stands there --
    -- exactly as the fight's own boxes do, so the two never draw over each other.
    local W = math.max(180, ((bounds and bounds.x) or 0) - 32)
    local gap = 8
    -- Under the host's ceiling AND under the phase's own control stack, which shares this column: a
    -- readout that grew up over the bell would cover the one control the phase cannot do without.
    local dockTop = math.max((bounds and bounds.dockTop) or 8, self:controlsBottom() + gap)
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
    -- The pointer has taken over the selection. Dropping the column focus means the next key press
    -- picks up from the tile the mouse is on rather than from a plate the player stopped steering
    -- several clicks ago -- the two devices hand the selection over instead of each keeping their own.
    self.focus = nil

    local control = self:controlAt(x, y)
    if control then self:press(control) return end

    -- A member already in hand from the keyboard drops wherever the click lands.
    local cx, cy = self.map:cellAt(x, y)
    if self.held then
        if cx then self:deployAt(self.held, cx, cy) end
        self.held = nil
        return
    end

    -- The board is the only thing that can start a drag now: there is no card to pick a body off.
    if cx then
        local p = self:deployedAt(cx, cy)
        if p then self.drag = { char = p.char, startX = x, startY = y, active = false } end
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
        else
            -- Dropped off the board. This used to WITHDRAW the body to the bench; there is no bench, so
            -- it is a refusal -- and a spoken one, because a drag that puts a body back where it started
            -- and says nothing reads as a drag the game failed to notice.
            self.message = "Everyone you brought down takes the field."
        end
        return
    end

    -- A click, not a drag: it picks the standing member up, and the next click drops them.
    self.held = drag.char
end

-- One navigation step. It crossed between two regions -- the strip and the board -- pushing up off the
-- cards onto the tiles and down off the bottom row back; with the strip gone there is one region and no
-- edge to cross at, so the whole of it is the board cursor. Which also retires the awkward part: the
-- crossing had to ask the MAP where the cursor sat on screen, because a board turned to put the party
-- at the bottom has some other grid row against the strip.
-- ...which leaves ONE edge to cross, and it is the board's own left side, into the control stack
-- standing beside it. Read off the cursor REFUSING to move: moveCursor clamps silently at the board's
-- edge, so a step left that changed nothing is a step off the left of the board, whichever way the
-- board is facing -- no caller has to ask the map where the cursor sits on screen, which is the part
-- the old strip crossing got wrong.
function DeployPhase:navigate(dx, dy)
    if self.focus then self:navigateColumn(dx, dy) return end
    local c = self.map.cursor
    local bx, by = c.x, c.y
    self.map:moveCursor(dx, dy)
    if dx < 0 and c.x == bx and c.y == by then self:enterColumn() end
end

-- THE WHEEL IS NOT BOUND ANY MORE. It paged the strip sideways when the company overflowed it; nothing
-- overflows and nothing pages. The host swallows the wheel while the phase is up rather than routing it
-- here (states/battle.lua's wheelmoved), so it cannot fall through to the fight underneath.

function DeployPhase:confirm()
    -- On a plate, confirm PRESSES it -- and only an enabled one answers, exactly as a click does
    -- (controlAt). A bell with nobody on the field is not a button that does nothing, it is not a button.
    if self.focus then
        local ctrl = self:focused()
        if ctrl and ctrl.enabled then self:press(ctrl.key) end
        return
    end
    local c = self.map.cursor
    if self.held then
        self:deployAt(self.held, c.x, c.y)
        self.held = nil
    else
        local p = self:deployedAt(c.x, c.y)
        if p then self.held = p.char end
    end
end

-- Backing out, in the order the player got into it: the plate first (the selection comes back to the
-- board), then the body in hand (they stay where they were standing), and with neither, the phase says
-- what it is waiting for. One ladder, shared by Esc and the pad's B, so the two never disagree about
-- what "back" means with a body in hand and a plate lit.
function DeployPhase:cancel()
    if self.focus then self.focus = nil
    elseif self.held then self.held = nil
    else self.message = "Set your line, then Begin Battle." end
end

function DeployPhase:keypressed(key)
    if key == "return" or key == "kpenter" then self:begin()
    elseif key == "escape" then self:cancel()
    elseif key == "space" then self:confirm()
    -- R for Reset Line, the one plate in the stack that had no key of its own -- the doc has claimed
    -- keyboard and pad reach all of it since the strip went, and this was the control making that a lie.
    -- It is on the selection ring now like every other plate; the letter is for the hand already on the
    -- arrows, which is where this phase's hands are.
    elseif key == "r" then self:press("autofill")
    -- V, the same key that flips whole-side auto inside the fight (states/battle.lua): one binding for
    -- one idea, before the bell and after it.
    elseif key == "v" then self:toggleAuto()
    -- F, the same key that steps the playback speed inside the fight -- and dead here for the same
    -- reason it is dead there: nothing is being watched until auto is armed.
    elseif key == "f" then self:cycleSpeed()
    -- I, the overworld's own Loadout key (states/game.lua): the screen it opens is the same screen,
    -- so it answers to the same letter before a fight as on the road to it.
    elseif key == "i" then self:press("loadout")
    elseif key == "left" or key == "a" then self:navigate(-1, 0)
    elseif key == "right" or key == "d" then self:navigate(1, 0)
    elseif key == "up" or key == "w" then self:navigate(0, -1)
    elseif key == "down" or key == "s" then self:navigate(0, 1)
    end
end

function DeployPhase:gamepadpressed(_, button)
    if button == "start" then self:begin()
    elseif button == "b" then self:cancel()
    elseif button == "a" then self:confirm()
    -- Y, not the fight's A: here A is already "pick up / place", and placement outranks a switch.
    elseif button == "y" then self:toggleAuto()
    -- Right-stick click cycles the speed, the fight's own binding for it -- one stick for one idea,
    -- before the bell and after it.
    elseif button == "rightstick" then self:cycleSpeed()
    -- X for the Loadout, since the overworld's Y is spoken for here. The other face buttons are the
    -- phase's own (place / drop), and the shoulder pair is not a place to hide a screen.
    elseif button == "x" then self:press("loadout")
    elseif button == "dpleft" then self:navigate(-1, 0)
    elseif button == "dpright" then self:navigate(1, 0)
    elseif button == "dpup" then self:navigate(0, -1)
    elseif button == "dpdown" then self:navigate(0, 1)
    end
end

-- A hand over anything that can be picked up or pressed: a member standing on the board, and the
-- column's controls.
function DeployPhase:cursorKind(x, y)
    if self:controlAt(x, y) then return "hand" end
    local cx, cy = self.map:cellAt(x, y)
    if cx and (self.held or self:deployedAt(cx, cy)) then return "hand" end
    return "arrow"
end

return DeployPhase
