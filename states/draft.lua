-- Draft mode: the Super-Auto-Pets-style roguelike-draft screen. Between rounds you spend a budget in
-- the store (drafting characters and gear scaled to the round), combine duplicates to strengthen them,
-- then Fight -- a piloted tactical battle on the moving-node control board against a round-scaled bot.
-- Three losses ends the run; ten wins takes it.
--
-- The RULES live in the model layer (models/draft_run, draft_shop, draft_match); this state is the
-- screen and the input over them. Mouse, keyboard and gamepad all drive it (the project standard): a
-- cursor walks a flat list of the interactive things on screen, and the mouse claims it on hover.
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
local Vendor = require("models.vendor")

local draft = {}

-- Seconds on each player's chess clock for a round. Generous for a piloted tactical turn, tight enough
-- that stalling loses.
draft.CHESS_SECONDS = 120

local titleFont = Theme.display(30)
local capFont = Theme.display(15)
local bodyFont = Theme.body(15)
local smallFont = Theme.body(12)

-- ---------------------------------------------------------------------------
-- Entry / run lifecycle
-- ---------------------------------------------------------------------------

function draft.enter(self, opts)
    opts = opts or {}
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

    draft.selectedUnit = nil
    draft.selectedGear = nil
    draft.message = nil
    draft.cursor = 1
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

-- ---------------------------------------------------------------------------
-- Actions
-- ---------------------------------------------------------------------------

local function buyUnit(entry)
    local char, why = DraftShop.buyUnit(draft.run, entry)
    say(char and ("Drafted " .. (char.name or char.id)) or ("Can't draft: " .. tostring(why)))
end

local function buyGear(entry)
    local item, why = DraftShop.buyGear(draft.run, entry)
    say(item and ("Bought " .. (item.name or item.id)) or ("Can't buy: " .. tostring(why)))
end

local function reroll()
    local ok, why = DraftShop.reroll(draft.run)
    if not ok then say("Can't reroll: " .. tostring(why)) end
end

-- Click a bench unit: equip the held gear onto it, or merge with the selected duplicate, or select it.
local function tapUnit(char)
    if draft.selectedGear then
        if Character.firstEmptySlot(char) then
            DraftShop.take(draft.run.stash, draft.selectedGear)
            Character.addItem(char, draft.selectedGear)
            say("Equipped " .. (draft.selectedGear.name or draft.selectedGear.id))
            draft.selectedGear = nil
        else
            say("That unit's grid is full.")
        end
        return
    end
    if draft.selectedUnit and DraftRun.canMergeUnits(draft.selectedUnit, char) then
        local res = DraftRun.mergeUnit(draft.run, draft.selectedUnit, char)
        say(res and ("Combined -- now level " .. res.toLevel) or "Can't combine those.")
        draft.selectedUnit = nil
    else
        draft.selectedUnit = (draft.selectedUnit == char) and nil or char
    end
end

-- Click a stash item: merge with the selected duplicate, or select it (to equip or merge next).
local function tapGear(item)
    if draft.selectedGear and DraftRun.canMergeItems(draft.selectedGear, item) then
        local merged = DraftRun.mergeItems(draft.selectedGear, item)
        DraftShop.take(draft.run.stash, draft.selectedGear)
        DraftShop.take(draft.run.stash, item)
        draft.run.stash[#draft.run.stash + 1] = merged
        say("Combined into " .. (merged.name or merged.id))
        draft.selectedGear = nil
    else
        draft.selectedUnit = nil
        draft.selectedGear = (draft.selectedGear == item) and nil or item
    end
end

-- Sell whatever is selected: a unit for a coin, gear for its resale value.
local function sellSelected()
    if draft.selectedUnit then
        DraftRun.removeUnit(draft.run, draft.selectedUnit)
        DraftRun.addGold(draft.run, 1)
        say("Sold for 1 gold.")
        draft.selectedUnit = nil
    elseif draft.selectedGear then
        local value = Vendor.sellValue(draft.selectedGear)
        DraftShop.take(draft.run.stash, draft.selectedGear)
        DraftRun.addGold(draft.run, value)
        say("Sold for " .. value .. " gold.")
        draft.selectedGear = nil
    else
        say("Select a unit or item to sell.")
    end
end

local function fight()
    local party = DraftRun.party(draft.run)
    if #party == 0 then say("Draft at least one unit first.") return end
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
local CARD_W, CARD_H = 132, 92

-- Add an interactive target: a rect with an activate (primary) and optional secondary (freeze/sell)
-- action, tagged so draw can style it and input can find it.
local function target(list, x, y, w, h, opts)
    list[#list + 1] = {
        x = x, y = y, w = w, h = h,
        activate = opts.activate, secondary = opts.secondary,
        kind = opts.kind, ref = opts.ref, label = opts.label,
    }
    return list[#list]
end

function draft:layout()
    local W = Scale.WIDTH
    local targets = {}
    self.rects = { store = { x = MARGIN, y = 84, w = W - MARGIN * 2, h = 236 } }

    if self.terminal then self.targets = targets; return end

    -- Store: a row of unit cards, then a row of gear cards.
    local sx, sy = MARGIN + 20, 132
    for _, entry in ipairs(self.run.shop and self.run.shop.units or {}) do
        target(targets, sx, sy, CARD_W, CARD_H, {
            kind = "shopUnit", ref = entry,
            activate = function() buyUnit(entry) end,
            secondary = function() DraftShop.toggleFreeze(entry) end,
        })
        sx = sx + CARD_W + 12
    end
    local gx, gy = MARGIN + 20, sy + CARD_H + 16
    for _, entry in ipairs(self.run.shop and self.run.shop.gear or {}) do
        target(targets, gx, gy, CARD_W, CARD_H, {
            kind = "shopGear", ref = entry,
            activate = function() buyGear(entry) end,
            secondary = function() DraftShop.toggleFreeze(entry) end,
        })
        gx = gx + CARD_W + 12
    end
    -- Reroll button, at the right edge of the store.
    target(targets, W - MARGIN - 150, gy + 24, 150, 40, {
        kind = "button", label = "Reroll (" .. DraftShop.REROLL_COST .. "g)", activate = reroll,
    })

    -- Bench: drafted units.
    self.rects.bench = { x = MARGIN, y = 344, w = 760, h = 200 }
    local bx, by = MARGIN + 20, 392
    for _, char in ipairs(self.run.bench or {}) do
        target(targets, bx, by, CARD_W, CARD_H, {
            kind = "benchUnit", ref = char, activate = function() tapUnit(char) end,
        })
        bx = bx + CARD_W + 12
        if bx + CARD_W > self.rects.bench.x + self.rects.bench.w then
            bx = MARGIN + 20; by = by + CARD_H + 12
        end
    end

    -- Stash: unequipped gear.
    self.rects.stash = { x = 820, y = 344, w = Scale.WIDTH - 820 - MARGIN, h = 200 }
    local tx, ty = self.rects.stash.x + 16, 392
    for _, item in ipairs(self.run.stash or {}) do
        target(targets, tx, ty, 118, 54, {
            kind = "stashGear", ref = item, activate = function() tapGear(item) end,
        })
        tx = tx + 118 + 10
        if tx + 118 > self.rects.stash.x + self.rects.stash.w then
            tx = self.rects.stash.x + 16; ty = ty + 54 + 10
        end
    end

    -- Bottom action bar.
    local by2 = 570
    target(targets, MARGIN, by2, 150, 44, { kind = "button", label = "Sell", activate = sellSelected })
    target(targets, W - MARGIN - 200, by2, 200, 44, { kind = "fight", label = "Fight", activate = fight })
    target(targets, W - MARGIN - 200 - 170, by2, 150, 44, { kind = "button", label = "Back", activate = backToMenu })

    self.targets = targets
    if self.cursor > #targets then self.cursor = #targets end
    if self.cursor < 1 then self.cursor = 1 end
end

-- ---------------------------------------------------------------------------
-- Update
-- ---------------------------------------------------------------------------

function draft.update(dt)
    draft:layout()
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

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

-- A card: a filled inset with a border that lights amber when hovered/cursored and blue when selected.
local function card(t, focused, selected)
    Theme.set(selected and Theme.slot or Theme.panel2)
    love.graphics.rectangle("fill", t.x, t.y, t.w, t.h, Theme.R, Theme.R)
    love.graphics.setLineWidth(focused and 2 or 1)
    if selected then Theme.set(Theme.cursor)
    elseif focused then Theme.set(Theme.accentAmber)
    else Theme.set(Theme.frame) end
    love.graphics.rectangle("line", t.x, t.y, t.w, t.h, Theme.R, Theme.R)
    love.graphics.setLineWidth(1)
end

-- Small item pips along a unit card's foot: one dot per non-empty grid cell, so a geared unit reads at
-- a glance without opening a full loadout grid.
local function drawPips(char, x, y, w)
    local n = Character.itemCount(char)
    for i = 1, math.min(n, 9) do
        Theme.set(Theme.accentAmber)
        love.graphics.rectangle("fill", x + (i - 1) * 9, y, 6, 6, 1, 1)
    end
end

local function drawUnitCard(t, char, focused)
    card(t, focused, draft.selectedUnit == char)
    love.graphics.setFont(bodyFont)
    Theme.set(Theme.ink)
    love.graphics.printf(Theme.ellipsize(char.name or char.id, bodyFont, t.w - 16), t.x + 8, t.y + 10, t.w - 16, "left")
    love.graphics.setFont(smallFont)
    Theme.set(Theme.muted)
    love.graphics.print("Lv " .. (char.level or 1), t.x + 8, t.y + t.h - 34)
    drawPips(char, t.x + 8, t.y + t.h - 14, t.w - 16)
end

local function drawShopCard(t, entry, focused)
    local afford = DraftRun.canAfford(draft.run, entry.price)
    card(t, focused, false)
    love.graphics.setFont(bodyFont)
    Theme.set(afford and Theme.ink or Theme.muted)
    love.graphics.printf(Theme.ellipsize(entry.name or entry.id, bodyFont, t.w - 16), t.x + 8, t.y + 10, t.w - 16, "left")
    love.graphics.setFont(smallFont)
    if entry.kind == "gear" then
        Theme.set(Theme.muted)
        love.graphics.print((entry.type or "gear") .. (entry.level and entry.level > 0 and (" +" .. entry.level) or ""), t.x + 8, t.y + 40)
    end
    Theme.set(afford and Theme.accentAmber or { 0.6, 0.4, 0.4 })
    love.graphics.print(entry.price .. "g", t.x + 8, t.y + t.h - 22)
    if entry.frozen then
        Theme.set(Theme.cursor)
        love.graphics.print("FROZEN", t.x + t.w - 8 - smallFont:getWidth("FROZEN"), t.y + t.h - 22)
    end
end

local function drawGearRow(t, item, focused)
    card(t, focused, draft.selectedGear == item)
    love.graphics.setFont(smallFont)
    Theme.set(Theme.ink)
    local name = (item.name or item.id) .. (item.level and item.level > 0 and (" +" .. item.level) or "")
    love.graphics.printf(Theme.ellipsize(name, smallFont, t.w - 12), t.x + 6, t.y + 8, t.w - 12, "left")
    Theme.set(Theme.muted)
    love.graphics.print(item.type or "", t.x + 6, t.y + t.h - 18)
end

local function drawButton(t, focused)
    Theme.set(t.kind == "fight" and { 0.30, 0.42, 0.30 } or Theme.panel2)
    love.graphics.rectangle("fill", t.x, t.y, t.w, t.h, Theme.R, Theme.R)
    love.graphics.setLineWidth(focused and 2 or 1)
    Theme.set(focused and Theme.accentAmber or Theme.frame)
    love.graphics.rectangle("line", t.x, t.y, t.w, t.h, Theme.R, Theme.R)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(bodyFont)
    Theme.set(Theme.ink)
    love.graphics.printf(t.label, t.x, t.y + t.h / 2 - bodyFont:getHeight() / 2, t.w, "center")
end

function draft.drawHeader()
    local run = draft.run
    love.graphics.setFont(titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.print("Draft -- Round " .. (run.round or 1), MARGIN, 24)

    love.graphics.setFont(bodyFont)
    Theme.set(Theme.ink)
    local status = string.format("Gold %d      Wins %d/%d      Lives %d/%d",
        run.gold or 0, run.wins or 0, DraftRun.WIN_TARGET,
        math.max(0, DraftRun.LIVES - (run.losses or 0)), DraftRun.LIVES)
    love.graphics.print(status, MARGIN + 320, 34)
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
    love.graphics.printf(draft.terminal == "won" and "Run Won!" or "Eliminated",
        x, y + 40, w, "center")
    love.graphics.setFont(bodyFont)
    Theme.set(Theme.ink)
    love.graphics.printf(draft.terminal == "won"
        and ("Ten wins. You took the draft in " .. (draft.run.round or 1) .. " rounds.")
        or ("Three losses at round " .. (draft.run.round or 1) .. ". The run is over."),
        x + 30, y + 96, w - 60, "center")
    -- The two exits are the layout's own targets in terminal mode.
    draft.termButtons = {
        { x = x + 60, y = y + 160, w = 180, h = 44, label = "New Run", activate = newRun },
        { x = x + w - 60 - 180, y = y + 160, w = 180, h = 44, label = "Back to Menu", activate = backToMenu },
    }
    for i, b in ipairs(draft.termButtons) do
        drawButton(b, draft.cursor == i)
    end
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
    panel(draft.rects.bench, "BENCH  --  click two of the same to combine")
    panel(draft.rects.stash, "STASH  --  select gear, then a unit to equip")

    local mouse = InputMode.isMouse()
    for i, t in ipairs(draft.targets) do
        local focused = (not mouse and draft.cursor == i) or (mouse and t.hovered)
        if t.kind == "shopUnit" then drawShopCard(t, t.ref, focused)
        elseif t.kind == "shopGear" then drawShopCard(t, t.ref, focused)
        elseif t.kind == "benchUnit" then drawUnitCard(t, t.ref, focused)
        elseif t.kind == "stashGear" then drawGearRow(t, t.ref, focused)
        else drawButton(t, focused) end
    end

    if draft.message then
        love.graphics.setFont(bodyFont)
        Theme.set(Theme.muted)
        love.graphics.printf(draft.message, MARGIN, 626, Scale.WIDTH - MARGIN * 2, "center")
    end

    love.graphics.setFont(smallFont)
    Theme.set(Theme.muted)
    love.graphics.printf("Enter/A: buy or select   ·   F/Y: freeze a store slot   ·   X: sell selected   ·   Esc/B: back",
        MARGIN, 664, Scale.WIDTH - MARGIN * 2, "center")

    draft.closeButton:draw()
    love.graphics.setColor(1, 1, 1)
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

local function hit(t, x, y) return x >= t.x and x <= t.x + t.w and y >= t.y and y <= t.y + t.h end

function draft.mousemoved(x, y)
    if draft.closeButton then draft.closeButton:mousemoved(x, y) end
    for _, t in ipairs(draft.targets) do t.hovered = hit(t, x, y) end
end

function draft.mousepressed(x, y, button)
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
            if button == 2 and t.secondary then t.secondary()
            elseif t.activate then t.activate() end
            return
        end
    end
end

function draft.cursorKind(x, y)
    if draft.closeButton and draft.closeButton:contains(x, y) then return "hand" end
    for _, t in ipairs(draft.targets) do if hit(t, x, y) then return "hand" end end
    return "arrow"
end

local function moveCursor(d)
    local n = #draft.targets
    if n == 0 then return end
    draft.cursor = ((draft.cursor - 1 + d) % n) + 1
end

function draft.keypressed(key)
    if draft.terminal then
        if key == "left" or key == "right" then draft.cursor = draft.cursor == 1 and 2 or 1
        elseif key == "return" or key == "kpenter" or key == "space" then
            (draft.termButtons[draft.cursor] or draft.termButtons[1]).activate()
        elseif key == "escape" then backToMenu() end
        return
    end
    if key == "escape" then backToMenu()
    elseif key == "left" or key == "a" then moveCursor(-1)
    elseif key == "right" or key == "d" then moveCursor(1)
    elseif key == "up" or key == "w" then moveCursor(-4)
    elseif key == "down" or key == "s" then moveCursor(4)
    elseif key == "return" or key == "kpenter" or key == "space" then
        local t = draft.targets[draft.cursor]; if t and t.activate then t.activate() end
    elseif key == "f" then
        local t = draft.targets[draft.cursor]; if t and t.secondary then t.secondary() end
    elseif key == "x" then sellSelected()
    elseif key == "r" then reroll()
    end
end

function draft.gamepadpressed(_, b)
    if draft.terminal then
        if b == "dpleft" or b == "dpright" then draft.cursor = draft.cursor == 1 and 2 or 1
        elseif b == "a" or b == "start" then (draft.termButtons[draft.cursor] or draft.termButtons[1]).activate()
        elseif b == "b" then backToMenu() end
        return
    end
    if b == "b" then backToMenu()
    elseif b == "dpleft" then moveCursor(-1)
    elseif b == "dpright" then moveCursor(1)
    elseif b == "dpup" then moveCursor(-4)
    elseif b == "dpdown" then moveCursor(4)
    elseif b == "a" then local t = draft.targets[draft.cursor]; if t and t.activate then t.activate() end
    elseif b == "y" then local t = draft.targets[draft.cursor]; if t and t.secondary then t.secondary() end
    elseif b == "x" then sellSelected()
    elseif b == "start" then fight()
    end
end

return draft
