-- Draft mode: the Super-Auto-Pets-style roguelike-draft screen. Between rounds you spend a budget in
-- the store (drafting characters and gear scaled to the round), arrange the four you field in a
-- MARCHING FORMATION with reserves on a bench, combine duplicates to strengthen them, then Fight -- a
-- piloted tactical battle on the moving-node control board against a round-scaled bot. Three losses
-- ends the run; ten wins takes it.
--
-- Like Super Auto Pets, the mouse drives this by DRAG, not click: drag a store card onto the formation
-- (or bench) to recruit, drag a unit onto a same-kind unit to combine, drag between cells to rearrange,
-- drag gear onto a unit to equip, and drag a unit or item onto Sell to cash it out. Keyboard and gamepad
-- can't drag, so they keep a pick-up / drop equivalent (the project's three-input standard): a cursor
-- walks the interactive things, confirm picks up or drops.
--
-- The RULES live in the model layer (models/draft_run, draft_shop, draft_match); this state is the
-- screen and the input over them. The FORMATION is the up-to-four fielded units seated by cell (front
-- row faces the enemy; models/arena.lua seats the party into exactly this shape via
-- DraftRun.formationSlots), the BENCH is the reserves behind them.
--
-- Flow: enter -> shop/arrange -> Fight -> states.battle -> (onWin/onLoss) -> back here for the next
-- round, or the terminal card when the run is decided. The run persists to disk after every battle, so
-- quitting mid-run and reopening Draft resumes it.

local State = require("states")
local Scale = require("scale")
local Theme = require("ui.theme")
local InputMode = require("input_mode")
local CloseButton = require("ui.close_button")
local DraftRun = require("models.draft_run")
local DraftShop = require("models.draft_shop")
local DraftMatch = require("models.draft_match")
local Character = require("models.character")
local Item = require("models.item")
local Sprite = require("models.sprite")
local ItemTooltip = require("ui.item_tooltip")
local ScreenFx = require("ui.screen_fx")

local draft = {}

-- Seconds on each player's chess clock for a round. Generous for a piloted tactical turn, tight enough
-- that stalling loses.
draft.CHESS_SECONDS = 120

local titleFont = Theme.display(30)
local capFont = Theme.display(15)
local bodyFont = Theme.body(15)
local smallFont = Theme.body(12)

local DRAG_THRESHOLD = 5 -- a press that never moves this far is a click, not a drag

-- ---------------------------------------------------------------------------
-- Entry / run lifecycle
-- ---------------------------------------------------------------------------

function draft.enter(self, opts)
    opts = opts or {}
    -- Clear any screen effects a battle left standing -- a lost fight fades the world to grey, and
    -- returning to the shop must open on full colour again rather than that defeat grey (ui/screen_fx.lua).
    ScreenFx.reset()
    if not opts.resume then
        -- Opened fresh from the menu: resume a saved run that is still in progress, else start a new one.
        local saved = DraftRun.read()
        draft.run = (saved and not DraftRun.outcome(saved)) and saved or DraftRun.new()
        if not draft.run.shop then DraftShop.roll(draft.run) end
    end
    -- On resume (returning from a battle) the run is already on the module and recordResult has advanced
    -- it; roll the new round's shop unless the run has ended.
    draft.terminal = DraftRun.outcome(draft.run)
    if opts.resume and not draft.terminal then DraftShop.roll(draft.run) end

    draft.held = nil          -- a unit picked up by keyboard/gamepad, awaiting a drop
    draft.selectedGear = nil  -- a stash item selected to equip / merge (keyboard, and mouse click-equip)
    draft.drag = nil          -- the mouse drag in flight (see mousepressed)
    draft.message = nil
    draft.cursor = 1
    draft.mx, draft.my = 0, 0
    draft.closeButton = CloseButton.new(Scale.WIDTH - 20, 20)
    draft.targets = {}
    draft:layout()
end

-- Bank a battle result and come back to the shop (or the terminal). Called from the battle's win/loss
-- exits. The run is persisted here so a quit right after a fight is not lost.
function draft.afterBattle(result)
    DraftRun.recordResult(draft.run, result)
    local ok = pcall(DraftRun.write, draft.run)
    if not ok then --[[ disk is best-effort; a failed write must not eat the result ]] end
    State.switch(require("states.draft"), { resume = true })
end

local function say(msg) draft.message = msg end
local function run() return draft.run end

-- ---------------------------------------------------------------------------
-- Actions on the run (buy / arrange / merge / sell)
-- ---------------------------------------------------------------------------

-- Recruit the store unit in `entry`, then (optionally) seat it where it was dropped. buyUnit auto-fills
-- the first free formation cell (or the bench when the formation is full); a `dest` re-seats it from
-- there so a drag lands the unit exactly where the player aimed.
local function recruitUnit(entry, dest)
    if DraftRun.rosterFull(draft.run) then say("No room -- sell a unit first.") return end
    local char, why = DraftShop.buyUnit(draft.run, entry)
    if not char then say("Can't draft: " .. tostring(why)) return end
    if dest and dest.kind == "cell" then
        DraftRun.placeInCell(draft.run, char, dest.cell)
    elseif dest and dest.kind == "bench" then
        DraftRun.benchUnit(draft.run, char)
    end
    say("Drafted " .. (char.name or char.id))
end

-- Recruit the store gear in `entry` (it lands in the stash), and equip it onto `unit` when one is named
-- (a drag that ended on a unit) and that unit has a free grid cell.
local function recruitGear(entry, unit)
    local item, why = DraftShop.buyGear(draft.run, entry)
    if not item then say("Can't buy: " .. tostring(why)) return end
    if unit and Character.firstEmptySlot(unit) then
        DraftShop.take(draft.run.stash, item)
        Character.addItem(unit, item)
        say("Bought & equipped " .. (item.name or item.id))
    else
        say("Bought " .. (item.name or item.id))
    end
end

-- Equip a stash `item` onto `unit`'s next free cell.
local function equipGear(item, unit)
    if not (item and unit) then return end
    if Character.firstEmptySlot(unit) then
        DraftShop.take(draft.run.stash, item)
        Character.addItem(unit, item)
        say("Equipped " .. (item.name or item.id))
        draft.selectedGear = nil
    else
        say("That unit's grid is full.")
    end
end

-- Drop `mover` (a fielded or benched unit) onto formation `cell`: combine with a same-kind occupant,
-- else move/swap into the cell (placeInCell refuses a fifth fielder onto an empty cell).
local function moveUnitToCell(mover, cell)
    local occ = draft.run.formation[cell]
    if occ and occ ~= mover and DraftRun.canMergeUnits(mover, occ) then
        local res = DraftRun.mergeUnit(draft.run, mover, occ)
        say(res and ("Combined -- now level " .. res.toLevel) or "Can't combine those.")
    elseif not DraftRun.placeInCell(draft.run, mover, cell) then
        say("Formation is full (" .. DraftRun.PARTY_MAX .. ").")
    end
end

-- Drop `mover` onto another unit `target`: combine same kinds, else demote the mover to the bench.
local function dropUnitOnUnit(mover, target)
    if mover == target then return end
    if DraftRun.canMergeUnits(mover, target) then
        local res = DraftRun.mergeUnit(draft.run, mover, target)
        say(res and ("Combined -- now level " .. res.toLevel) or "Can't combine those.")
    else
        local tc = DraftRun.cellOf(draft.run, target)
        if tc then moveUnitToCell(mover, tc) end
    end
end

-- Send a fielded unit to the bench.
local function benchMover(mover)
    if DraftRun.cellOf(draft.run, mover) and not DraftRun.benchUnit(draft.run, mover) then
        say("Bench is full.")
    end
end

local function sellUnit(u)
    DraftRun.removeUnit(draft.run, u)
    DraftRun.addGold(draft.run, 1)
    say("Sold for 1 gold.")
end

local function sellGear(item)
    local value = DraftShop.gearSellValue(item)
    DraftShop.take(draft.run.stash, item)
    DraftRun.addGold(draft.run, value)
    draft.selectedGear = nil
    say("Sold for " .. value .. " gold.")
end

-- Merge two stash items (same id + level) into one a level higher.
local function mergeGear(a, b)
    local merged = DraftRun.mergeItems(a, b)
    if not merged then return false end
    DraftShop.take(draft.run.stash, a)
    DraftShop.take(draft.run.stash, b)
    draft.run.stash[#draft.run.stash + 1] = merged
    say("Combined into " .. (merged.name or merged.id))
    draft.selectedGear = nil
    return true
end

local function reroll()
    local ok, why = DraftShop.reroll(draft.run)
    if not ok then say("Can't reroll: " .. tostring(why)) end
end

-- Open the shared Loadout panel (ui/panels/party.lua) to arrange a member's 3x3 item grid -- the same
-- screen the campaign uses, run over a SYNTHETIC player so it never touches the real save (the debug
-- character editor drives it the same way). The roster is every drafted unit (fielded + benched) and the
-- pool is the run stash, all the very same instances the run holds, so grid edits, equips and stows
-- land straight on the units and stash the draft already owns -- nothing to copy back on close.
function draft.openLoadout(focusChar)
    local units = {}
    for _, c in ipairs(DraftRun.party(draft.run)) do units[#units + 1] = c end
    for _, c in ipairs(draft.run.bench or {}) do units[#units + 1] = c end
    if #units == 0 then say("Draft a unit first.") return end

    local Party = require("ui.panels.party")
    local synthetic = {
        roster = units,
        party = DraftRun.party(draft.run), -- the fielded ones, so the panel badges who takes the field
        stash = draft.run.stash,
        gold = 0, prestige = draft.run.round or 1, materials = {}, recipes = {},
    }
    draft.panel = Party.new({
        player = synthetic,
        title = "Loadout",
        tactics = false, -- draft is player-piloted; the grid (and its adjacency) is the whole point here
        persist = false, -- a synthetic player must never reach the save file
        onClose = function() draft.panel = nil end,
    })
    if focusChar then
        for i, c in ipairs(units) do
            if c == focusChar then draft.panel:focusChar(i) break end
        end
    end
end

local function fight()
    if #DraftRun.party(draft.run) == 0 then say("Field at least one unit first.") return end
    local match = DraftMatch.find(draft.run, nil)
    State.switch(require("states.battle"), DraftMatch.battleOpts(draft.run, match, {
        chessClock = draft.CHESS_SECONDS,
        onWin = function() draft.afterBattle("win") end,
        onLoss = function() draft.afterBattle("loss") end,
    }))
end

local function backToMenu() State.switch(require("states.menu")) end
local function newRun() draft.run = nil; State.switch(require("states.draft")) end

-- ---------------------------------------------------------------------------
-- Layout (builds the interactive target list, shared by draw and by input)
-- ---------------------------------------------------------------------------

local MARGIN = 40
local CARD_W, CARD_H = 132, 84       -- a store card
local ICON = 44                      -- the icon square on a store / formation card
local FCELL, FGAP = 72, 10           -- a formation cell
local BCELL, BGAP = 58, 8            -- a bench cell

-- Add an interactive target: a rect with an activate (primary) and optional secondary (freeze) action,
-- tagged so draw can style it and input can find it.
local function target(list, x, y, w, h, opts)
    list[#list + 1] = {
        x = x, y = y, w = w, h = h,
        kind = opts.kind, ref = opts.ref, unit = opts.unit, label = opts.label,
        activate = opts.activate, secondary = opts.secondary, draggable = opts.draggable,
    }
    return list[#list]
end

function draft:layout()
    local W = Scale.WIDTH
    local targets = {}
    self.rects = {
        store = { x = MARGIN, y = 76, w = W - MARGIN * 2, h = 210 },
        form = { x = MARGIN, y = 296, w = 740, h = 268 },
        stash = { x = 800, y = 296, w = W - 800 - MARGIN, h = 268 },
    }

    if self.terminal then self.targets = targets; return end

    -- Store: a row of unit cards, then a row of gear cards.
    local sx, sy = MARGIN + 20, 108
    for _, entry in ipairs(self.run.shop and self.run.shop.units or {}) do
        target(targets, sx, sy, CARD_W, CARD_H, {
            kind = "shopUnit", ref = entry, draggable = true,
            activate = function() recruitUnit(entry) end,
            secondary = function() DraftShop.toggleFreeze(entry) end,
        })
        sx = sx + CARD_W + 12
    end
    local gx, gy = MARGIN + 20, sy + CARD_H + 6
    for _, entry in ipairs(self.run.shop and self.run.shop.gear or {}) do
        target(targets, gx, gy, CARD_W, CARD_H, {
            kind = "shopGear", ref = entry, draggable = true,
            activate = function() recruitGear(entry) end,
            secondary = function() DraftShop.toggleFreeze(entry) end,
        })
        gx = gx + CARD_W + 12
    end
    -- Reroll button, at the right edge of the store.
    target(targets, W - MARGIN - 150, gy + 22, 150, 40, {
        kind = "button", label = "Reroll (" .. DraftShop.REROLL_COST .. "g)", activate = reroll,
    })

    -- Formation: the marching grid. Every cell is a target (so an empty one is a drop / cursor stop);
    -- an occupied cell is also a drag source.
    self.formGridX = MARGIN + 84
    self.formGridY = 332
    for cell = 1, DraftRun.FORMATION_CELLS do
        local col, row = DraftRun.cellToColRow(cell)
        local cx = self.formGridX + (col - 1) * (FCELL + FGAP)
        local cy = self.formGridY + (row - 1) * (FCELL + FGAP)
        local occupant = self.run.formation and self.run.formation[cell]
        target(targets, cx, cy, FCELL, FCELL, {
            kind = "cell", ref = cell, unit = occupant, draggable = occupant ~= nil,
        })
    end

    -- Bench: reserves in a row under the formation.
    self.benchY = self.formGridY + DraftRun.FORMATION_ROWS * (FCELL + FGAP) + 26
    local bx = MARGIN + 20
    for _, char in ipairs(self.run.bench or {}) do
        target(targets, bx, self.benchY, BCELL, BCELL, {
            kind = "benchUnit", ref = char, unit = char, draggable = true,
        })
        bx = bx + BCELL + BGAP
    end
    -- A trailing empty bench slot: the keyboard/pad drop point for demoting a held fielded unit (mouse
    -- uses the whole bench region). Present only while there is room.
    self.benchDropX = bx
    if not DraftRun.benchFull(self.run) then
        target(targets, bx, self.benchY, BCELL, BCELL, { kind = "benchDrop" })
    end

    -- Stash: unequipped gear, one small row-card each.
    local st = self.rects.stash
    local tx, ty = st.x + 16, st.y + 40
    for _, item in ipairs(self.run.stash or {}) do
        target(targets, tx, ty, 118, 54, { kind = "stashGear", ref = item, draggable = true })
        tx = tx + 118 + 10
        if tx + 118 > st.x + st.w then tx = st.x + 16; ty = ty + 54 + 10 end
    end

    -- Bottom action bar. Sell is also a drop zone (drag a unit / item onto it).
    local by = 580
    target(targets, MARGIN, by, 150, 44, { kind = "sell", label = "Sell", activate = function()
        if draft.held then sellUnit(draft.held); draft.held = nil
        elseif draft.selectedGear then sellGear(draft.selectedGear)
        else say("Pick up a unit or item to sell.") end
    end })
    target(targets, MARGIN + 160, by, 170, 44, { kind = "button", label = "Loadout", activate = function() draft.openLoadout() end })
    target(targets, W - MARGIN - 200, by, 200, 44, { kind = "fight", label = "Fight", activate = fight })
    target(targets, W - MARGIN - 200 - 170, by, 150, 44, { kind = "button", label = "Back", activate = backToMenu })

    self.targets = targets
    if self.cursor > #targets then self.cursor = #targets end
    if self.cursor < 1 then self.cursor = 1 end
end

-- ---------------------------------------------------------------------------
-- Update
-- ---------------------------------------------------------------------------

local function hit(t, x, y) return x >= t.x and x <= t.x + t.w and y >= t.y and y <= t.y + t.h end

function draft.update(dt)
    draft:layout()
    -- Re-apply mouse hover after the rebuild: layout mints fresh target tables (hovered = nil) every
    -- frame, and a stationary pointer fires no mousemoved to set it -- so a card hovered without moving
    -- would lose its highlight AND its tooltip. Recompute from the last known mouse position.
    if InputMode.isMouse() and draft.mx then
        for _, t in ipairs(draft.targets) do t.hovered = hit(t, draft.mx, draft.my) end
    end
    if draft.panel and draft.panel.update then draft.panel:update(dt) end
end

-- ---------------------------------------------------------------------------
-- Drawing helpers
-- ---------------------------------------------------------------------------

local TYPE_COLOR = {
    weapon = { 0.789, 0.361, 0.354 },
    armor = { 0.391, 0.549, 0.812 },
    consumable = { 0.361, 0.671, 0.480 },
    ability = { 0.568, 0.414, 0.786 },
    utility = { 0.865, 0.707, 0.341 },
}
local UNIT_COLOR = { 0.68, 0.62, 0.42 }

-- Resolve the art for a unit or gear id through the memoized loader; a missing file comes back a
-- string (not userdata), which drawIcon renders as a tinted initial plate.
local function spriteFor(defs, id)
    local def = id and defs[id]
    return def and Sprite.load(def.sprite) or nil
end

-- Draw a `size`-square icon at (x, y): the art if we have it, else a type-tinted plate with the
-- entry's initial -- so a card reads at a glance even before its sprite is commissioned.
local function drawIcon(x, y, size, sprite, label, tint)
    Theme.set(Theme.slot)
    love.graphics.rectangle("fill", x, y, size, size, 4, 4)
    if type(sprite) == "userdata" then
        love.graphics.setColor(1, 1, 1)
        local iw, ih = sprite:getDimensions()
        local s = math.min((size - 6) / iw, (size - 6) / ih)
        love.graphics.draw(sprite, x + size / 2, y + size / 2, 0, s, s, iw / 2, ih / 2)
    else
        local c = tint or UNIT_COLOR
        love.graphics.setColor(c[1] * 0.5, c[2] * 0.5, c[3] * 0.5)
        love.graphics.rectangle("fill", x + 2, y + 2, size - 4, size - 4, 3, 3)
        love.graphics.setFont(capFont)
        love.graphics.setColor(c[1], c[2], c[3])
        love.graphics.printf((label or "?"):sub(1, 1):upper(), x, y + size / 2 - capFont:getHeight() / 2, size, "center")
    end
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", x, y, size, size, 4, 4)
end

local function panel(r, caption)
    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, Theme.R, Theme.R)
    if caption then
        love.graphics.setFont(capFont)
        Theme.set(Theme.accentAmber)
        love.graphics.print(caption, r.x + 14, r.y + 10)
    end
end

-- A card frame: filled inset, border amber when focused and blue when selected.
local function cardFrame(t, focused, selected)
    Theme.set(selected and Theme.slot or Theme.panel2)
    love.graphics.rectangle("fill", t.x, t.y, t.w, t.h, Theme.R, Theme.R)
    love.graphics.setLineWidth(focused and 2 or 1)
    if selected then Theme.set(Theme.cursor)
    elseif focused then Theme.set(Theme.accentAmber)
    else Theme.set(Theme.frame) end
    love.graphics.rectangle("line", t.x, t.y, t.w, t.h, Theme.R, Theme.R)
    love.graphics.setLineWidth(1)
end

-- Item pips along a unit token's foot: one per non-empty grid cell, so a geared unit reads at a glance.
local function drawPips(char, x, y)
    local n = Character.itemCount(char)
    Theme.set(Theme.accentAmber)
    for i = 1, math.min(n, 9) do
        love.graphics.rectangle("fill", x + (i - 1) * 8, y, 5, 5, 1, 1)
    end
end

local function drawShopCard(t, entry, focused)
    local afford = DraftRun.canAfford(draft.run, entry.price)
    cardFrame(t, focused, false)
    local isUnit = entry.kind == "unit"
    local sprite = isUnit and spriteFor(Character.defs, entry.id) or spriteFor(Item.defs, entry.id)
    local tint = isUnit and UNIT_COLOR or (TYPE_COLOR[entry.type] or UNIT_COLOR)
    drawIcon(t.x + 8, t.y + 8, ICON, sprite, entry.name or entry.id, tint)
    local tx, tw = t.x + ICON + 16, t.w - ICON - 24
    love.graphics.setFont(bodyFont)
    Theme.set(afford and Theme.ink or Theme.muted)
    love.graphics.printf(Theme.ellipsize(entry.name or entry.id, bodyFont, tw), tx, t.y + 10, tw, "left")
    love.graphics.setFont(smallFont)
    if entry.kind == "gear" then
        Theme.set(Theme.muted)
        love.graphics.print((entry.type or "gear") .. (entry.level and entry.level > 0 and (" +" .. entry.level) or ""), tx, t.y + 32)
    end
    Theme.set(afford and Theme.accentAmber or { 0.6, 0.4, 0.4 })
    love.graphics.print(entry.price .. "g", t.x + 8, t.y + t.h - 22)
    if entry.frozen then
        Theme.set(Theme.cursor)
        love.graphics.print("FROZEN", t.x + t.w - 8 - smallFont:getWidth("FROZEN"), t.y + t.h - 22)
    end
end

-- A unit token (formation cell / bench cell): icon, name, and a front/back-tinted frame. `held` hides
-- the occupant (it is riding the cursor). `size` picks the compact bench look vs the roomier cell.
local function drawUnitToken(t, char, size, opts)
    opts = opts or {}
    local cx, cy = t.x, t.y
    Theme.set(Theme.panel2)
    love.graphics.rectangle("fill", cx, cy, size, size, 6, 6)

    if char and not opts.held then
        local iconSize = size - 20
        drawIcon(cx + (size - iconSize) / 2, cy + 4, iconSize, spriteFor(Character.defs, char.id), char.name or char.id, UNIT_COLOR)
        love.graphics.setFont(smallFont)
        Theme.set(Theme.ink)
        love.graphics.printf(Theme.ellipsize(char.name or char.id, smallFont, size - 6), cx + 3, cy + size - 16, size - 6, "center")
        drawPips(char, cx + 5, cy + size - 22)
    elseif opts.held then
        love.graphics.setFont(smallFont)
        Theme.set(Theme.muted)
        love.graphics.printf("moving...", cx, cy + size / 2 - 8, size, "center")
    end

    love.graphics.setLineWidth(opts.focused and 2 or 1)
    if opts.selected then Theme.set(Theme.cursor)
    elseif opts.focused then Theme.set(Theme.accentAmber)
    else Theme.set(opts.frame or Theme.frame) end
    love.graphics.rectangle("line", cx, cy, size, size, 6, 6)
    love.graphics.setLineWidth(1)
end

local function drawGearRow(t, item, focused, selected)
    cardFrame(t, focused, selected)
    local gi = 36
    drawIcon(t.x + 6, t.y + (t.h - gi) / 2, gi, spriteFor(Item.defs, item.id), item.name or item.id, TYPE_COLOR[item.type] or UNIT_COLOR)
    local tx, tw = t.x + gi + 12, t.w - gi - 18
    love.graphics.setFont(smallFont)
    Theme.set(Theme.ink)
    local name = (item.name or item.id) .. (item.level and item.level > 0 and (" +" .. item.level) or "")
    love.graphics.printf(Theme.ellipsize(name, smallFont, tw), tx, t.y + 8, tw, "left")
    Theme.set(Theme.muted)
    love.graphics.print(item.type or "", tx, t.y + t.h - 18)
end

local function drawButton(t, focused, hot)
    Theme.set(t.kind == "fight" and { 0.30, 0.42, 0.30 } or (hot and Theme.slot or Theme.panel2))
    love.graphics.rectangle("fill", t.x, t.y, t.w, t.h, Theme.R, Theme.R)
    love.graphics.setLineWidth(focused and 2 or 1)
    Theme.set(focused and Theme.accentAmber or Theme.frame)
    love.graphics.rectangle("line", t.x, t.y, t.w, t.h, Theme.R, Theme.R)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(bodyFont)
    Theme.set(Theme.ink)
    love.graphics.printf(t.label, t.x, t.y + t.h / 2 - bodyFont:getHeight() / 2, t.w, "center")
end

-- ---------------------------------------------------------------------------
-- Tooltips (gear reuses the shared item tooltip; a unit gets a compact sheet)
-- ---------------------------------------------------------------------------

local previewGear = {}
local function gearInstance(entry)
    local key = entry.id .. "@" .. (entry.level or 0)
    if previewGear[key] == nil then previewGear[key] = Item.instantiate(entry.id, nil, entry.level) end
    return previewGear[key]
end

local previewUnit = {}
local function unitInstance(entry)
    if previewUnit[entry.id] == nil then previewUnit[entry.id] = Character.instantiate(entry.id) end
    return previewUnit[entry.id]
end

local UNIT_STATS = {
    { key = "health", label = "HP", res = true },
    { key = "mana", label = "MP", res = true },
    { key = "stamina", label = "SP", res = true },
    { key = "damage", label = "Attack" },
    { key = "magicDamage", label = "Magic" },
    { key = "defense", label = "Defense" },
    { key = "magicDefense", label = "M.Def" },
    { key = "movement", label = "Move" },
    { key = "speed", label = "Speed" },
}

local function statText(char, r)
    local v = char.stats and char.stats[r.key]
    if r.res then
        if type(v) ~= "table" then return nil end
        return tostring(v.max or 0)
    end
    if type(v) ~= "number" or v == 0 then return nil end
    return tostring(v)
end

local function drawUnitTooltip(char, mx, my)
    local title, body, small = Theme.display(15), Theme.body(12), Theme.body(11)
    local pad, w = 9, 220
    local titleH, bodyH = title:getHeight(), body:getHeight()

    local rows = {}
    for _, r in ipairs(UNIT_STATS) do
        local text = statText(char, r)
        if text then rows[#rows + 1] = { label = r.label, value = text } end
    end
    local gear = {}
    for i = 1, Character.MAX_INVENTORY do
        local it = char.inventory and char.inventory[i]
        if it then gear[#gear + 1] = it.name or it.id end
    end

    local statRows = math.ceil(#rows / 2)
    local h = pad + titleH + 3 + bodyH + 6
        + statRows * (bodyH + 2)
        + (#gear > 0 and (8 + bodyH + #gear * bodyH) or 0)
        + pad

    local bx = mx + 14
    local maxX = Scale.WIDTH - w - 4
    if bx > maxX then bx = mx - w - 14 end
    bx = math.max(4, math.min(bx, maxX))
    local by = math.max(4, math.min(my + 16, Scale.HEIGHT - h - 4))

    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", bx, by, w, h, 4, 4)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", bx, by, w, h, 4, 4)

    local ty = by + pad
    love.graphics.setFont(title)
    Theme.set(Theme.accentAmber)
    love.graphics.print(char.name or char.id, bx + pad, ty)
    ty = ty + titleH + 3
    love.graphics.setFont(small)
    Theme.set(Theme.muted)
    local classLine = (char.class and (char.class:gsub("^%l", string.upper)) or "Adventurer")
        .. "   Lv " .. (char.level or 1)
    love.graphics.print(classLine, bx + pad, ty)
    ty = ty + bodyH + 6

    love.graphics.setFont(body)
    local colW = (w - pad * 2) / 2
    for i, r in ipairs(rows) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local rx = bx + pad + col * colW
        local ry = ty + row * (bodyH + 2)
        Theme.set(Theme.muted)
        love.graphics.print(r.label, rx, ry)
        Theme.set(Theme.ink)
        love.graphics.printf(r.value, rx, ry, colW - 10, "right")
    end
    ty = ty + statRows * (bodyH + 2)

    if #gear > 0 then
        ty = ty + 8
        Theme.set(Theme.accentAmber)
        love.graphics.print("Equipped", bx + pad, ty)
        ty = ty + bodyH
        Theme.set(Theme.ink)
        for _, name in ipairs(gear) do
            love.graphics.print(Theme.ellipsize(name, body, w - pad * 2), bx + pad, ty)
            ty = ty + bodyH
        end
    end
    love.graphics.setColor(1, 1, 1)
end

-- The target the pointer (mouse) or the cursor (keyboard/gamepad) is on -- what a tooltip describes.
local function hoveredTarget()
    if InputMode.isMouse() then
        for _, t in ipairs(draft.targets) do if t.hovered then return t end end
        return nil
    end
    return draft.targets[draft.cursor]
end

function draft.drawTooltip()
    if draft.panel then return end -- the loadout panel owns the screen; its own tooltips run instead
    if draft.drag and draft.drag.active then return end -- a drag in flight owns the cursor, not a tooltip
    local t = hoveredTarget()
    if not t then return end
    local mouse = InputMode.isMouse()
    local ax = mouse and (draft.mx or t.x + t.w) or (t.x + t.w)
    local ay = mouse and (draft.my or t.y) or t.y

    if t.kind == "shopGear" then ItemTooltip.draw(gearInstance(t.ref), ax, ay, Scale.WIDTH)
    elseif t.kind == "stashGear" then ItemTooltip.draw(t.ref, ax, ay, Scale.WIDTH)
    elseif t.kind == "shopUnit" then drawUnitTooltip(unitInstance(t.ref), ax, ay)
    elseif (t.kind == "cell" or t.kind == "benchUnit") and t.unit then drawUnitTooltip(t.unit, ax, ay)
    end
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

function draft.drawHeader()
    local r = draft.run
    love.graphics.setFont(titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.print("Draft -- Round " .. (r.round or 1), MARGIN, 24)

    love.graphics.setFont(bodyFont)
    Theme.set(Theme.ink)
    local status = string.format("Gold %d      Wins %d/%d      Lives %d/%d",
        r.gold or 0, r.wins or 0, DraftRun.WIN_TARGET,
        math.max(0, DraftRun.LIVES - (r.losses or 0)), DraftRun.LIVES)
    love.graphics.print(status, MARGIN + 320, 34)
end

-- The formation grid + a caption. Front row (top) faces the enemy; its cells get a warmer frame.
function draft.drawFormation()
    local r = draft.rects.form
    panel(r, "FORMATION  --  the four you field  (drag to arrange)")

    love.graphics.setFont(smallFont)
    Theme.set(Theme.muted)
    love.graphics.print("^ front line (faces the enemy)", draft.formGridX, draft.formGridY - 16)
    -- FRONT / BACK row tags to the left of the grid.
    for row = 1, DraftRun.FORMATION_ROWS do
        local cy = draft.formGridY + (row - 1) * (FCELL + FGAP)
        Theme.set(Theme.muted)
        love.graphics.printf(row == 1 and "FRONT" or "BACK", MARGIN + 6, cy + FCELL / 2 - 8, 74, "right")
    end

    -- Bench caption.
    Theme.set(Theme.accentAmber)
    love.graphics.setFont(capFont)
    love.graphics.print("BENCH  --  reserves & merge fodder", MARGIN + 20, draft.benchY - 22)
end

function draft.drawTerminal()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)
    local w, h = 520, 240
    local x, y = Scale.WIDTH / 2 - w / 2, Scale.HEIGHT / 2 - h / 2
    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", x, y, w, h, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", x, y, w, h, Theme.R, Theme.R)
    love.graphics.setFont(titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf(draft.terminal == "won" and "Run Won!" or "Eliminated", x, y + 40, w, "center")
    love.graphics.setFont(bodyFont)
    Theme.set(Theme.ink)
    love.graphics.printf(draft.terminal == "won"
        and ("Ten wins. You took the draft in " .. (draft.run.round or 1) .. " rounds.")
        or ("Three losses at round " .. (draft.run.round or 1) .. ". The run is over."),
        x + 30, y + 96, w - 60, "center")
    draft.termButtons = {
        { x = x + 60, y = y + 160, w = 180, h = 44, label = "New Run", activate = newRun },
        { x = x + w - 60 - 180, y = y + 160, w = 180, h = 44, label = "Back to Menu", activate = backToMenu },
    }
    for i, b in ipairs(draft.termButtons) do drawButton(b, draft.cursor == i) end
end

function draft.draw()
    Theme.set(Theme.slot)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    draft.drawHeader()

    if draft.terminal then
        draft.drawTerminal()
        love.graphics.setColor(1, 1, 1)
        return
    end

    panel(draft.rects.store, "STORE")
    draft.drawFormation()
    panel(draft.rects.stash, "STASH  --  drag gear onto a unit to equip")

    local mouse = InputMode.isMouse()
    for i, t in ipairs(draft.targets) do
        local focused = (not mouse and draft.cursor == i) or (mouse and t.hovered)
        local dragging = draft.drag and draft.drag.active and draft.drag.origin == t
        if t.kind == "shopUnit" or t.kind == "shopGear" then
            drawShopCard(t, t.ref, focused)
        elseif t.kind == "cell" then
            local frame = select(2, DraftRun.cellToColRow(t.ref)) == 1 and { 0.72, 0.6, 0.4 } or Theme.frame
            drawUnitToken(t, t.unit, FCELL, {
                focused = focused, frame = frame,
                held = (t.unit and (t.unit == draft.held or dragging)),
            })
        elseif t.kind == "benchUnit" then
            drawUnitToken(t, t.unit, BCELL, {
                focused = focused,
                held = (t.unit == draft.held or dragging),
            })
        elseif t.kind == "benchDrop" then
            Theme.set(draft.held and Theme.accentAmber or Theme.frame, 0.4)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", t.x, t.y, t.w, t.w, 6, 6)
        elseif t.kind == "stashGear" then
            drawGearRow(t, t.ref, focused, draft.selectedGear == t.ref)
        elseif t.kind == "sell" then
            local hot = focused or (draft.drag and draft.drag.active and hit(t, draft.mx, draft.my))
            drawButton(t, focused, hot)
        else
            drawButton(t, focused)
        end
    end

    -- Prompt / status line.
    local line = draft.message
    if not line and draft.held then line = "Moving " .. (draft.held.name or "unit") .. " -- pick a cell, the bench, or Sell." end
    if not line and draft.selectedGear then line = "Holding " .. (draft.selectedGear.name or "gear") .. " -- pick a unit to equip, or Sell." end
    if line then
        love.graphics.setFont(bodyFont)
        Theme.set(Theme.muted)
        love.graphics.printf(line, MARGIN, 632, Scale.WIDTH - MARGIN * 2, "center")
    end

    love.graphics.setFont(smallFont)
    Theme.set(Theme.muted)
    local hint = InputMode.isGamepad()
        and "A: pick up / place / buy   ·   Y: freeze   ·   X: sell held   ·   Loadout button: edit items   ·   Start: Fight   ·   B: back"
        or "Drag to draft & arrange   ·   Click a unit (or L): edit items   ·   Right-click: freeze   ·   Esc: back"
    love.graphics.printf(hint, MARGIN, 668, Scale.WIDTH - MARGIN * 2, "center")

    draft.closeButton:draw()

    -- The dragged card rides the cursor above everything.
    if draft.drag and draft.drag.active then draft.drawDragGhost() end

    draft.drawTooltip()

    -- The Loadout panel is a modal over the whole screen (mirrors the hub's activePanel), drawn last so
    -- it sits on top of the shop behind it.
    if draft.panel then draft.panel:draw() end
    love.graphics.setColor(1, 1, 1)
end

function draft.drawDragGhost()
    local d = draft.drag
    local x, y = draft.mx, draft.my
    if d.kind == "shopUnit" then
        drawIcon(x - 22, y - 22, ICON, spriteFor(Character.defs, d.ref.id), d.ref.name, UNIT_COLOR)
    elseif d.kind == "unit" then
        drawIcon(x - 22, y - 22, ICON, spriteFor(Character.defs, d.ref.id), d.ref.name, UNIT_COLOR)
    elseif d.kind == "shopGear" then
        drawIcon(x - 18, y - 18, 36, spriteFor(Item.defs, d.ref.id), d.ref.name, TYPE_COLOR[d.ref.type] or UNIT_COLOR)
    elseif d.kind == "gear" then
        drawIcon(x - 18, y - 18, 36, spriteFor(Item.defs, d.ref.id), d.ref.name, TYPE_COLOR[d.ref.type] or UNIT_COLOR)
    end
end

-- ---------------------------------------------------------------------------
-- Input -- mouse (drag-driven)
-- ---------------------------------------------------------------------------

-- What is under (x, y) as a DROP target (a superset of the click targets: also the bench and stash
-- regions as a whole, so a drop into empty bench space still lands).
local function dropTargetAt(x, y)
    for _, t in ipairs(draft.targets) do
        if hit(t, x, y) then
            if t.kind == "cell" then return { kind = "cell", cell = t.ref, unit = t.unit }
            elseif t.kind == "benchUnit" then return { kind = "benchUnit", unit = t.unit }
            elseif t.kind == "benchDrop" then return { kind = "bench" }
            elseif t.kind == "stashGear" then return { kind = "unitless" } -- gear onto gear: no equip
            elseif t.kind == "sell" then return { kind = "sell" }
            end
        end
    end
    local f, s = draft.rects.form, draft.rects.stash
    -- Below the formation grid (the bench band) counts as the bench.
    if f and x >= f.x and x <= f.x + f.w and draft.benchY and y >= draft.benchY - 22 and y <= draft.benchY + BCELL then
        return { kind = "bench" }
    end
    if f and hit({ x = f.x, y = f.y, w = f.w, h = f.h }, x, y) then return { kind = "formationArea" } end
    if s and hit({ x = s.x, y = s.y, w = s.w, h = s.h }, x, y) then return { kind = "stashArea" } end
    return nil
end

-- Resolve a completed drag onto its drop.
local function resolveDrop(d, drop)
    if d.kind == "shopUnit" then
        if not drop then return end
        if drop.kind == "cell" then recruitUnit(d.ref, { kind = "cell", cell = drop.cell })
        elseif drop.kind == "bench" or drop.kind == "benchUnit" then recruitUnit(d.ref, { kind = "bench" })
        elseif drop.kind == "formationArea" then recruitUnit(d.ref) end
    elseif d.kind == "shopGear" then
        if not drop then return end
        if drop.kind == "cell" and drop.unit then recruitGear(d.ref, drop.unit)
        elseif drop.kind == "benchUnit" then recruitGear(d.ref, drop.unit)
        elseif drop.kind == "stashArea" or drop.kind == "unitless" then recruitGear(d.ref, nil) end
    elseif d.kind == "unit" then
        if not drop then return end
        if drop.kind == "sell" then sellUnit(d.ref)
        elseif drop.kind == "cell" then moveUnitToCell(d.ref, drop.cell)
        elseif drop.kind == "benchUnit" and drop.unit then dropUnitOnUnit(d.ref, drop.unit)
        elseif drop.kind == "bench" then benchMover(d.ref) end
    elseif d.kind == "gear" then
        if not drop then return end
        if drop.kind == "sell" then sellGear(d.ref)
        elseif drop.kind == "cell" and drop.unit then equipGear(d.ref, drop.unit)
        elseif drop.kind == "benchUnit" and drop.unit then equipGear(d.ref, drop.unit) end
    end
end

function draft.mousemoved(x, y)
    if draft.panel then draft.panel:mousemoved(x, y) return end
    draft.mx, draft.my = x, y
    if draft.closeButton then draft.closeButton:mousemoved(x, y) end
    for _, t in ipairs(draft.targets) do t.hovered = hit(t, x, y) end
    local d = draft.drag
    if d and not d.active and (math.abs(x - d.startX) > DRAG_THRESHOLD or math.abs(y - d.startY) > DRAG_THRESHOLD) then
        d.active = true
    end
end

function draft.mousepressed(x, y, button)
    if draft.panel then draft.panel:mousepressed(x, y, button) return end
    draft:layout()
    if draft.terminal then
        for _, b in ipairs(draft.termButtons or {}) do
            if hit(b, x, y) then b.activate() return end
        end
        return
    end
    if draft.closeButton and draft.closeButton:mousepressed(x, y, button) then backToMenu() return end

    for _, t in ipairs(draft.targets) do
        if hit(t, x, y) then
            if button == 2 then
                if t.secondary then t.secondary() end
                return
            end
            -- Buttons act on press; draggable things begin a potential drag; a plain stash click selects.
            if t.kind == "button" or t.kind == "sell" or t.kind == "fight" then
                if t.activate then t.activate() end
            elseif t.draggable then
                local kind = (t.kind == "shopUnit" and "shopUnit")
                    or (t.kind == "shopGear" and "shopGear")
                    or (t.kind == "stashGear" and "gear")
                    or "unit"
                local ref = t.unit or t.ref
                draft.drag = { kind = kind, ref = ref, origin = t, startX = x, startY = y, active = false }
            end
            return
        end
    end
    -- A click into empty space clears a keyboard pickup / selection.
    draft.held, draft.selectedGear = nil, nil
end

function draft.mousereleased(x, y, button)
    if draft.panel then if draft.panel.mousereleased then draft.panel:mousereleased(x, y, button) end return end
    if button ~= 1 then draft.drag = nil; return end
    local d = draft.drag
    draft.drag = nil
    if not d then return end
    if d.active then
        resolveDrop(d, dropTargetAt(x, y))
    else
        -- A press that never dragged is a click. Recruiting is drag-only (SAP); a stash item can be
        -- click-selected to equip/merge, and a plain click on an owned unit opens its Loadout (drag it
        -- to MOVE, click it to EDIT).
        if d.kind == "gear" then
            if draft.selectedGear and DraftRun.canMergeItems(draft.selectedGear, d.ref) then
                mergeGear(draft.selectedGear, d.ref)
            else
                draft.selectedGear = (draft.selectedGear == d.ref) and nil or d.ref
            end
        elseif d.kind == "unit" then
            if draft.selectedGear then equipGear(draft.selectedGear, d.ref)
            else draft.openLoadout(d.ref) end
        end
    end
end

function draft.wheelmoved(x, y)
    if draft.panel and draft.panel.wheelmoved then draft.panel:wheelmoved(x, y) end
end

function draft.cursorKind(_, x, y)
    if draft.panel then return draft.panel.cursorKind and draft.panel:cursorKind(x, y) or "arrow" end
    if draft.closeButton and draft.closeButton:contains(x, y) then return "hand" end
    for _, t in ipairs(draft.targets) do
        if hit(t, x, y) and t.kind ~= "benchDrop" then return "hand" end
    end
    return "arrow"
end

-- ---------------------------------------------------------------------------
-- Input -- keyboard / gamepad (pick-up / drop)
-- ---------------------------------------------------------------------------

local function moveCursor(d)
    local n = #draft.targets
    if n == 0 then return end
    draft.cursor = ((draft.cursor - 1 + d) % n) + 1
end

-- Confirm on the cursored target: buy, pick up, drop, equip, or press a button, per its kind.
local function confirm()
    local t = draft.targets[draft.cursor]
    if not t then return end
    if t.kind == "shopUnit" or t.kind == "shopGear" or t.kind == "button" or t.kind == "fight" or t.kind == "sell" then
        if t.activate then t.activate() end
        return
    end
    if t.kind == "cell" or t.kind == "benchUnit" then
        if draft.held then
            if t.kind == "cell" then moveUnitToCell(draft.held, t.ref)
            elseif t.unit then dropUnitOnUnit(draft.held, t.unit) end
            draft.held = nil
        elseif draft.selectedGear then
            if t.unit then equipGear(draft.selectedGear, t.unit) end
        elseif t.unit then
            draft.held = t.unit
        end
    elseif t.kind == "benchDrop" then
        if draft.held then benchMover(draft.held); draft.held = nil end
    elseif t.kind == "stashGear" then
        if draft.selectedGear and DraftRun.canMergeItems(draft.selectedGear, t.ref) then
            mergeGear(draft.selectedGear, t.ref)
        else
            draft.selectedGear = (draft.selectedGear == t.ref) and nil or t.ref
        end
    end
end

function draft.keypressed(key)
    if draft.panel then draft.panel:keypressed(key) return end
    if draft.terminal then
        if key == "left" or key == "right" then draft.cursor = draft.cursor == 1 and 2 or 1
        elseif key == "return" or key == "kpenter" or key == "space" then
            (draft.termButtons[draft.cursor] or draft.termButtons[1]).activate()
        elseif key == "escape" then backToMenu() end
        return
    end
    if key == "escape" then
        if draft.held or draft.selectedGear then draft.held, draft.selectedGear = nil, nil else backToMenu() end
    elseif key == "left" or key == "a" then moveCursor(-1)
    elseif key == "right" or key == "d" then moveCursor(1)
    elseif key == "up" or key == "w" then moveCursor(-4)
    elseif key == "down" or key == "s" then moveCursor(4)
    elseif key == "return" or key == "kpenter" or key == "space" then confirm()
    elseif key == "f" then
        local t = draft.targets[draft.cursor]; if t and t.secondary then t.secondary() end
    elseif key == "x" then
        if draft.held then sellUnit(draft.held); draft.held = nil
        elseif draft.selectedGear then sellGear(draft.selectedGear) end
    elseif key == "r" then reroll()
    elseif key == "l" then
        local t = draft.targets[draft.cursor]
        draft.openLoadout(t and t.unit or nil)
    end
end

function draft.gamepadpressed(joystick, b)
    if draft.panel then draft.panel:gamepadpressed(joystick, b) return end
    if draft.terminal then
        if b == "dpleft" or b == "dpright" then draft.cursor = draft.cursor == 1 and 2 or 1
        elseif b == "a" or b == "start" then (draft.termButtons[draft.cursor] or draft.termButtons[1]).activate()
        elseif b == "b" then backToMenu() end
        return
    end
    if b == "b" then
        if draft.held or draft.selectedGear then draft.held, draft.selectedGear = nil, nil else backToMenu() end
    elseif b == "dpleft" then moveCursor(-1)
    elseif b == "dpright" then moveCursor(1)
    elseif b == "dpup" then moveCursor(-4)
    elseif b == "dpdown" then moveCursor(4)
    elseif b == "a" then confirm()
    elseif b == "y" then local t = draft.targets[draft.cursor]; if t and t.secondary then t.secondary() end
    elseif b == "x" then
        if draft.held then sellUnit(draft.held); draft.held = nil
        elseif draft.selectedGear then sellGear(draft.selectedGear) end
    elseif b == "start" then fight()
    end
end

return draft
