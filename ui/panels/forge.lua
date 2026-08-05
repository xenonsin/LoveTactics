-- The Forge pop-up panel: the one bench in the city, and the only screen that spends materials.
-- Lists everything the player owns that a level can improve -- across each roster member's 3x3 grid
-- and the stash -- as cards down the left, and on the right lays the highlighted thing's whole path
-- out as a TRACK: one node per level 0..10, the rung it stands on filled, the rungs past the player's
-- standing dashed out (ui/forge_track.lua).
--
--   local panel = Forge.new({ player = p, onClose = fn })
--
-- THREE CATEGORIES, because the bench does three kinds of work and one flat list of 40 rows is not a
-- list anybody reads (models/forge.lua):
--   Gear        weapons, armor, utility -- per instance, swapped in place for a fresh "+n"
--   Abilities   per instance too. Used to be the class vendor's Upgrade tab.
--   Recipes     consumables, per TYPE -- refine the recipe and every copy bought after comes at that
--               tier. Only consumables the player actually holds are listed.
-- The segment strip is the same widget the shop uses for Buy/Sell, down to the Tab / LB-RB bindings.
--
-- AIM: the player may scrub the track to a rung further up and buy the whole climb in one commit
-- (Forge.costTo prices it, Forge.upgradeTo charges it once and refuses before spending anything).
-- RECIPES DO NOT BATCH -- Forge.recipeCost/refineRecipe are per-tier and read a blueprint rather than
-- an instance, so a recipe row pins `aim` at the next tier and the track is a readout only. Better a
-- category that plainly does one rung than a bill that promises three and charges for one.
--
-- This replaced a pair of tables: a list of identical plates each carrying one concatenated string,
-- and ui/growth_ladder.lua's 11-row x N-column sheet of every stat at every level. The numbers were
-- exact and unreadable; what a bench is actually asked is "where am I", "how far can I go" and "what
-- does this rung buy", and only the last of those is a number.

local Character = require("models.character")
local CloseButton = require("ui.close_button")
local Colors = require("ui.colors")
local Discipline = require("models.discipline")
local FootprintDiagram = require("ui.footprint_diagram")
local Forge = require("models.forge")
local ForgeTrack = require("ui.forge_track")
local InputMode = require("input_mode")
local Item = require("models.item")
local Material = require("models.material")
local MaterialTooltip = require("ui.material_tooltip")
local Player = require("models.player")
local Scale = require("scale")
local Sound = require("models.sound")
local Sprite = require("models.sprite")
local Theme = require("ui.theme")
local Vendor = require("models.vendor")

local ForgePanel = {}
ForgePanel.__index = ForgePanel

local BOX_W, BOX_H = 1120, 620
local LIST_W = 340
local CARD_H, CARD_GAP, MAX_VISIBLE = 54, 6, 7
local CONTENT_TOP = 112 -- below the title and the category strip

local MODES = { "gear", "ability", "recipe" }
local MODE_LABEL = { gear = "Gear", ability = "Abilities", recipe = "Recipes" }
local EMPTY_LABEL = {
    gear = "No weapons, armor or gear to forge.",
    ability = "No abilities to hone.",
    recipe = "No recipes to refine.",
}

local DIM = Theme.muted
local MARK = Theme.accentAmber
local UP = { 0.55, 0.90, 0.58 }  -- an improvement: kept heal-green (semantic)
local SHORT = { 0.88, 0.48, 0.44 } -- a track of the bill the player cannot pay

-- The icon well's tint when a piece has no art yet, so a wall of placeholder plates still reads by
-- kind. Same five-way split the stash grid and the shop use.
local TYPE_COLOR = {
    weapon = { 0.78, 0.42, 0.36 },
    armor = { 0.42, 0.55, 0.78 },
    consumable = { 0.44, 0.70, 0.50 },
    ability = { 0.57, 0.41, 0.79 },
    utility = { 0.80, 0.68, 0.38 },
}

local function pointIn(r, x, y)
    return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function ForgePanel.new(opts)
    opts = opts or {}
    local self = setmetatable({}, ForgePanel)
    self.onClose = opts.onClose
    self.player = opts.player
    self.title = opts.title or "The Forge"
    self.mode = "gear"

    self.titleFont = Theme.display(28)
    self.nameFont = Theme.display(22)
    self.cardFont = Theme.display(16)
    self.bodyFont = Theme.body(13)
    self.smallFont = Theme.body(11)
    self.capFont = Theme.body(10)
    self.bigFont = Theme.display(32)

    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - BOX_H / 2

    self.listLeft = self.boxX + 24
    self.detailX = self.listLeft + LIST_W + 24
    self.detailW = self.boxX + BOX_W - 24 - self.detailX

    self.modeY = self.boxY + 66
    self.modeH = 30
    self.segRects = {}
    local segW = LIST_W / #MODES
    for i, m in ipairs(MODES) do
        self.segRects[m] = { x = self.listLeft + (i - 1) * segW, y = self.modeY, w = segW, h = self.modeH }
    end

    self.sel, self.scroll = 1, 0
    self.chipRects = {}
    self.mx, self.my = -1, -1
    self:refresh()
    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)
    return self
end

-- ---------------------------------------------------------------------------
-- Rows
-- ---------------------------------------------------------------------------

-- Everything the player owns that passes `predicate`, each with where it lives so an upgrade can swap
-- it back in place: a roster member's grid cell, or a stash slot.
function ForgePanel:collect(predicate)
    local out = {}
    for _, char in ipairs(self.player.roster or {}) do
        for cell = 1, Character.MAX_INVENTORY do
            local item = char.inventory[cell]
            if item and predicate(item) then
                out[#out + 1] = { item = item, where = char.name or "?",
                    loc = { kind = "grid", char = char, cell = cell } }
            end
        end
    end
    for i, item in ipairs(self.player.stash or {}) do
        if predicate(item) then
            out[#out + 1] = { item = item, where = "Stash", loc = { kind = "stash", index = i } }
        end
    end
    return out
end

-- The distinct consumable blueprints the player holds anywhere. A recipe is per-TYPE, so five potions
-- in three places are one row -- keyed by id, listed in a stable order.
function ForgePanel:collectRecipes()
    local seen, ids = {}, {}
    local function note(item)
        if item and Forge.canRefine(item) and not seen[item.id] then
            seen[item.id] = true
            ids[#ids + 1] = item.id
        end
    end
    for _, char in ipairs(self.player.roster or {}) do
        for cell = 1, Character.MAX_INVENTORY do note(char.inventory[cell]) end
    end
    for _, item in ipairs(self.player.stash or {}) do note(item) end
    table.sort(ids)
    return ids
end

-- A billing key in words. It is a discipline id for the deep cut and a class id for ordinary stock, so
-- the discipline name is tried first and title-casing is the fallback -- "plague_knight" is "Plague
-- Knight", which title-casing alone would render "Plague_knight".
local function keyLabel(key)
    if not key then return "" end
    return Discipline.displayName(key) or (key:gsub("^%l", string.upper))
end

-- The cost in a card's right column: what the NEXT rung costs, or why there isn't one. Anything
-- belonging to a house is billed in technique, so the tail names the house it is owed to -- "40 Ninja",
-- "30 Knight" -- and only classless stock still shows a plain "160g".
local function costTail(cost)
    if not cost then return "fully forged", "max" end
    if cost.locked then return "standing", "locked" end
    if cost.technique > 0 then
        return cost.technique .. " " .. keyLabel(cost.techniqueId), nil
    end
    return cost.gold .. "g", nil
end

-- Rebuild self.rows for the current category. Called on open, on category switch, and after every
-- forge so spent gold and materials are reflected without reopening.
function ForgePanel:refresh()
    local keep = self.sel or 1
    self.rows = {}

    if self.mode == "recipe" then
        for _, id in ipairs(self:collectRecipes()) do
            local level = Player.recipeLevel(self.player, id)
            local sample = Item.instantiate(id, nil, level)
            local cost = Forge.recipeCost(self.player, id)
            local tail, state = costTail(cost)
            self.rows[#self.rows + 1] = { kind = "recipe", id = id, item = sample, level = level,
                cost = cost, tail = tail, state = state, where = "recipe" }
        end
    else
        local wantAbility = (self.mode == "ability")
        for _, up in ipairs(self:collect(function(item)
            return Forge.canWork(item) and ((item.type == "ability") == wantAbility)
        end)) do
            local cost = Forge.upgradeCost(self.player, up.item)
            local tail, state = costTail(cost)
            self.rows[#self.rows + 1] = { kind = "instance", item = up.item, up = up,
                level = up.item.level or 0, cost = cost, tail = tail, state = state, where = up.where }
        end
    end

    self.sel = math.max(1, math.min(keep, #self.rows))
    self:scrollToSelection()
    self:resetAim()
end

function ForgePanel:hasRows() return self.rows and #self.rows > 0 end
function ForgePanel:current() return self.rows and self.rows[self.sel] end

-- Point the scrub at the next rung whenever the selected row changes: aiming is a per-item question,
-- and carrying a "+7" across from the last thing you looked at would price a climb nobody asked for.
function ForgePanel:resetAim()
    local row = self:current()
    self.aim = row and math.min((row.level or 0) + 1, Item.MAX_LEVEL) or nil
    self.hoverAim = nil
    self.growthId, self.growth = nil, nil
end

function ForgePanel:setMode(mode)
    self.mode = mode
    self.sel, self.scroll = 1, 0
    -- The last result named an item this category does not list, so it stops meaning anything here.
    self.message, self.messageOk = nil, nil
    self:refresh()
end

function ForgePanel:cycleMode(delta)
    local idx = 1
    for i, m in ipairs(MODES) do if m == self.mode then idx = i end end
    self:setMode(MODES[(idx - 1 + delta) % #MODES + 1])
end

function ForgePanel:setMsg(text, ok) self.message, self.messageOk = text, ok end

function ForgePanel:close()
    if self.onClose then self.onClose() end
end

-- ---------------------------------------------------------------------------
-- The list: selection + scrolling
-- ---------------------------------------------------------------------------

function ForgePanel:canScroll() return #self.rows > MAX_VISIBLE end

function ForgePanel:visibleCount() return math.min(MAX_VISIBLE, #self.rows) end

-- The selection leads and the window follows -- never the other way round (ui/menu.lua's rule).
function ForgePanel:scrollToSelection()
    if not self:canScroll() then self.scroll = 0 return end
    local maxScroll = #self.rows - MAX_VISIBLE
    if self.sel <= self.scroll then
        self.scroll = self.sel - 1
    elseif self.sel > self.scroll + MAX_VISIBLE then
        self.scroll = self.sel - MAX_VISIBLE
    end
    self.scroll = math.max(0, math.min(maxScroll, self.scroll))
end

function ForgePanel:scrollBy(delta)
    if not self:canScroll() then return end
    self.scroll = math.max(0, math.min(#self.rows - MAX_VISIBLE, self.scroll + delta))
end

-- Move the selection by delta, wrapping. The cursor blip fires here rather than at each of the input
-- paths that move a selection, so keyboard, pad and mouse cannot drift on which movements are audible.
function ForgePanel:moveSelection(delta)
    if #self.rows == 0 then return end
    local before = self.sel
    self.sel = (self.sel - 1 + delta) % #self.rows + 1
    self:scrollToSelection()
    if self.sel ~= before then
        Sound.play("ui.move")
        self:resetAim()
    end
end

-- The card rect for row `i`, or nil when it is scrolled out of the window (which takes it out of
-- hit-testing and drawing for free).
function ForgePanel:cardRect(i)
    if i <= self.scroll or i > self.scroll + self:visibleCount() then return nil end
    local row = i - self.scroll - 1
    return { x = self.listLeft, y = self.boxY + CONTENT_TOP + row * (CARD_H + CARD_GAP),
        w = LIST_W, h = CARD_H }
end

-- ---------------------------------------------------------------------------
-- Aim
-- ---------------------------------------------------------------------------

-- A recipe pins at the next tier (no batching); everything else may be scrubbed anywhere above where
-- it stands, INCLUDING past the ceiling -- the whole path stays inspectable, and the bill says
-- "locked" rather than the track pretending those rungs are not there.
function ForgePanel:setAim(level)
    local row = self:current()
    if not row then return end
    local floorLevel = (row.level or 0) + 1
    if row.kind == "recipe" then self.aim = math.min(floorLevel, Item.MAX_LEVEL) return end
    self.aim = math.max(floorLevel, math.min(level, Item.MAX_LEVEL))
end

function ForgePanel:nudgeAim(delta)
    local row = self:current()
    if not row or row.kind == "recipe" then return end
    local before = self.aim
    -- The keyboard is taking over, so the pointer's opinion stops counting: nudging from a hovered
    -- rung rather than the picked one would move the aim somewhere the player never chose.
    self.hoverAim = nil
    self:setAim((self.aim or (row.level or 0) + 1) + delta)
    if self.aim ~= before then Sound.play("ui.move") end
end

-- Point the pointer at a rung WITHOUT picking it. Everything downstream reads previewLevel(), so the
-- whole right-hand side answers for the rung under the cursor and snaps back when it leaves.
function ForgePanel:setHoverAim(level)
    local row = self:current()
    if not row or row.kind == "recipe" then self.hoverAim = nil return end
    -- Only rungs that are actually buyable are worth previewing; pointing at one already paid for
    -- has nothing to say.
    if level and level > (row.level or 0) then self.hoverAim = level else self.hoverAim = nil end
end

-- THE ONE LEVEL EVERYTHING READS. The rung under the pointer if there is one, else the rung picked.
--
-- The bill, the button's label AND the commit all go through this, deliberately: if the pane can
-- preview one climb while Enter buys a different one, the screen is lying about what it is selling.
-- The mouse cannot reach the Forge button without leaving the track (which clears the hover), so by
-- the time the button is clickable it is always showing the picked rung.
function ForgePanel:previewLevel()
    local row = self:current()
    if not row then return nil end
    if row.kind == "recipe" then return self.aim end
    return self.hoverAim or self.aim
end

-- The bill for what is currently previewed: a summed climb for an instance, one tier for a recipe.
function ForgePanel:aimedCost()
    local row = self:current()
    if not row then return nil end
    if row.kind == "recipe" then return row.cost end
    return Forge.costTo(self.player, row.item, self:previewLevel())
end

-- ---------------------------------------------------------------------------
-- The ceiling, in words
-- ---------------------------------------------------------------------------

function ForgePanel:ceilingReason(item)
    local class = Item.classOf(item)
    if class then
        local vendorId = Forge.houseVendorFor(class)
        local house = vendorId and (Vendor.get(vendorId) or {}).name or "its house"
        return "Complete more of " .. house .. "'s quests to forge past this."
    end
    return "Locked."
end

-- What this thing's ladder is measured against: the bank that bills it and who on the roster is
-- carrying that bank. A DISCIPLINE item stops there -- it has no ceiling left, and the only question is
-- whether the technique is there. A plain class item adds the ceiling its house's standing sets, which
-- is a separate gate from the price and survives it (see Forge.ceilingFor).
function ForgePanel:standingLine(item)
    local key = (item.discipline and Discipline.defs[item.discipline] and item.discipline)
        or Item.classOf(item)
    if not key then return nil end

    local name = keyLabel(key)
    local holder, held = Discipline.techniqueHolder(self.player, key)
    local bank = holder and (held .. " held by " .. (holder.name or "?")) or "none banked yet"

    if item.discipline and Discipline.defs[item.discipline] then
        return name .. " - " .. bank
    end
    return name .. " - " .. bank .. ", ceiling +" .. Forge.ceilingFor(self.player, item)
end

-- ---------------------------------------------------------------------------
-- Transactions
-- ---------------------------------------------------------------------------

function ForgePanel:refusal(reason, item)
    if reason == "gold" then return "Not enough gold." end
    if reason == "technique" then
        local key = (item.discipline and Discipline.defs[item.discipline] and item.discipline)
            or Item.classOf(item)
        local name = key and keyLabel(key) or "that house"
        return "Not enough technique. Fight with " .. name .. " gear to bank more."
    end
    if reason == "materials" then return "Not enough materials." end
    if reason == "locked" then return self:ceilingReason(item) end
    if reason == "max level" then return (item.name or "That") .. " is at maximum level." end
    return "It cannot be forged."
end

function ForgePanel:commit()
    local row = self:current()
    if not row then return end
    if row.kind == "recipe" then self:refine(row) else self:upgrade(row) end
end

-- Forge the highlighted instance up to the aimed rung in ONE commit, swap the fresh instance into the
-- slot it came from, and save. Forge.upgradeTo prices the whole climb and refuses before spending
-- anything, so a batch cannot leave the player having paid for rungs it did not deliver.
function ForgePanel:upgrade(row)
    local up = row.up
    -- previewLevel, never self.aim: what the bill just showed is what gets bought.
    local newItem, reason = Forge.upgradeTo(self.player, up.item, self:previewLevel())
    if not newItem then
        self:setMsg(self:refusal(reason, up.item), false)
        return
    end
    if up.loc.kind == "grid" then
        up.loc.char.inventory[up.loc.cell] = newItem
    else
        self.player.stash[up.loc.index] = newItem
    end
    Player.save()
    -- A non-nil reason alongside an item means the climb stopped short; place what we got and say so.
    if reason then
        self:setMsg(self:refusal(reason, newItem), false)
    else
        self:setMsg(newItem.name .. " forged.", true)
    end
    self:refresh()
end

function ForgePanel:refine(row)
    local level, reason = Forge.refineRecipe(self.player, row.id)
    if not level then
        self:setMsg(self:refusal(reason, row.item), false)
        return
    end
    Player.save()
    self:setMsg(row.item.name .. " recipe refined to +" .. level .. ".", true)
    self:refresh()
end

-- ---------------------------------------------------------------------------
-- Draw
-- ---------------------------------------------------------------------------

function ForgePanel:update(dt)
    -- Analog stick navigation (left stick Y), with edge detection so holding the stick advances one
    -- card per push rather than racing the list.
    local moved = false
    for _, joystick in ipairs(love.joystick.getJoysticks()) do
        if joystick:isGamepad() then
            local y = joystick:getGamepadAxis("lefty")
            if y <= -0.5 then
                if not self.axisActive then self:moveSelection(-1) end
                moved = true
            elseif y >= 0.5 then
                if not self.axisActive then self:moveSelection(1) end
                moved = true
            end
        end
    end
    self.axisActive = moved
end

function ForgePanel:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    Theme.plate(self.boxX, self.boxY, BOX_W, BOX_H, Theme.R)

    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf(self.title, self.boxX, self.boxY + 18, BOX_W, "center")

    love.graphics.setFont(self.bodyFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf(self.player.gold .. " gold", self.boxX, self.modeY + 8, BOX_W - 24, "right")

    self:drawModeSelector()

    if self:hasRows() then
        self:drawList()
        self:drawDetail()
    else
        -- An empty category draws no track, no chips and no button, so drop the rects that would
        -- otherwise keep answering clicks on behalf of whatever was listed a moment ago.
        self.track, self.forgeRect, self.chipRects = nil, nil, {}
        love.graphics.setFont(self.bodyFont)
        Theme.set(Theme.muted)
        love.graphics.printf(EMPTY_LABEL[self.mode] or "Nothing to forge.",
            self.listLeft, self.boxY + 220, LIST_W, "center")
    end

    if self.message then
        love.graphics.setFont(self.bodyFont)
        if self.messageOk then love.graphics.setColor(UP[1], UP[2], UP[3])
        else love.graphics.setColor(SHORT[1], SHORT[2], SHORT[3]) end
        love.graphics.printf(self.message, self.boxX, self.boxY + BOX_H - 52, BOX_W, "center")
    end

    love.graphics.setFont(self.smallFont)
    Theme.set(Theme.muted)
    local hint = InputMode.isGamepad()
        and "A: forge    D-pad up/down: pick    left/right: aim a rung    LB/RB: category    B: close"
        or "Hover a rung to preview, click to pick    Enter: forge    Tab: category    Esc: close"
    love.graphics.printf(hint, self.boxX, self.boxY + BOX_H - 30, BOX_W, "center")

    self.closeButton:draw()

    -- The material tooltip goes last, over the close button and everything else: it is a hover
    -- readout and must never be painted under the chrome it is explaining.
    if self.hoverMaterial then
        MaterialTooltip.draw(self.hoverMaterial, self.mx, self.my,
            self.boxX + BOX_W, self.player)
    end
    love.graphics.setColor(1, 1, 1)
end

function ForgePanel:drawModeSelector()
    love.graphics.setFont(self.bodyFont)
    for _, m in ipairs(MODES) do
        local r = self.segRects[m]
        local active = (self.mode == m)
        Theme.set(active and Theme.panel or Theme.panel2)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, Theme.R, Theme.R)
        love.graphics.setLineWidth(active and 1.5 or 1)
        Theme.set(active and Theme.accentAmber or Theme.frame)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, Theme.R, Theme.R)
        love.graphics.setLineWidth(1)
        Theme.set(active and Theme.accentAmber or Theme.muted)
        love.graphics.printf(MODE_LABEL[m], r.x, r.y + r.h / 2 - self.bodyFont:getHeight() / 2, r.w, "center")
    end
end

-- An item's art in `box` px, centred and uniformly scaled; a tinted plate carrying its initial when
-- there is no art yet (models/sprite.lua hands back the path string rather than an Image).
function ForgePanel:drawIcon(item, x, y, box)
    local spr = item.sprite
    if type(spr) == "string" then spr = Sprite.load(spr) end
    Theme.set(Theme.slot)
    love.graphics.rectangle("fill", x, y, box, box, 3, 3)
    if type(spr) == "userdata" then
        local iw, ih = spr:getDimensions()
        local s = math.min((box - 8) / iw, (box - 8) / ih)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(spr, x + box / 2, y + box / 2, 0, s, s, iw / 2, ih / 2)
    else
        local tint = TYPE_COLOR[item.type] or Theme.muted
        love.graphics.setColor(tint[1], tint[2], tint[3], 0.5)
        love.graphics.rectangle("fill", x + 3, y + 3, box - 6, box - 6, 2, 2)
        local font = Theme.display(math.floor(box * 0.5))
        love.graphics.setFont(font)
        Theme.set(Theme.ink, 0.85)
        love.graphics.printf((item.name or "?"):sub(1, 1), x, y + box / 2 - font:getHeight() / 2, box, "center")
    end
    Theme.set(Theme.hairline)
    love.graphics.rectangle("line", x, y, box, box, 3, 3)
end

-- One card per row: art, name, where it lives, and a right column carrying the level it stands on
-- over what the next rung costs. A row that cannot be worked right now is drawn DIM rather than
-- washed over -- a real disabled state, which is what the old plate list could not express.
function ForgePanel:drawList()
    for i, row in ipairs(self.rows) do
        local r = self:cardRect(i)
        if r then
            local selected = (i == self.sel)
            local off = (row.state ~= nil)
            local alpha = off and 0.45 or 1

            Theme.set(selected and Theme.panel or Theme.panel2, alpha)
            love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 4, 4)
            love.graphics.setLineWidth(selected and 1.5 or 1)
            Theme.set(selected and Theme.accentAmber or Theme.hairline, alpha)
            love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 4, 4)
            love.graphics.setLineWidth(1)

            love.graphics.setColor(1, 1, 1, alpha)
            self:drawIcon(row.item, r.x + 8, r.y + 8, 38)

            local tx = r.x + 54
            local tw = r.w - 54 - 76
            local font, name = Theme.fitText(Theme.display, row.item.name or "?", tw, 16, 12)
            love.graphics.setFont(font)
            Theme.set(selected and Theme.accentAmber or Theme.ink, alpha)
            love.graphics.print(name, tx, r.y + 9)

            love.graphics.setFont(self.smallFont)
            Theme.set(Theme.muted, alpha)
            local sub = row.kind == "recipe" and "recipe" or (row.item.type .. "  ·  " .. row.where)
            love.graphics.print(Theme.ellipsize(sub, self.smallFont, tw), tx, r.y + 31)

            -- Right column: where it stands, over what the next rung asks.
            love.graphics.setFont(self.bodyFont)
            Theme.set(Theme.accentAmber, alpha)
            love.graphics.printf("+" .. (row.level or 0), r.x, r.y + 8, r.w - 10, "right")
            love.graphics.setFont(self.smallFont)
            if row.state == "max" then love.graphics.setColor(UP[1], UP[2], UP[3], alpha)
            elseif row.state == "locked" then love.graphics.setColor(SHORT[1], SHORT[2], SHORT[3], alpha)
            else Theme.set(Theme.muted, alpha) end
            love.graphics.printf(row.tail, r.x, r.y + 31, r.w - 10, "right")
        end
    end
    self:drawScrollHints()
    love.graphics.setColor(1, 1, 1)
end

-- Carets above / below the list when there are cards out of sight, so it never silently hides itself.
function ForgePanel:drawScrollHints()
    if not self:canScroll() then return end
    local cx = self.listLeft + LIST_W / 2
    local first = self:cardRect(self.scroll + 1)
    local last = self:cardRect(self.scroll + self:visibleCount())
    Theme.set(Theme.muted)
    if self.scroll > 0 and first then
        love.graphics.polygon("fill", cx - 7, first.y - 6, cx + 7, first.y - 6, cx, first.y - 13)
    end
    if last and self.scroll + self:visibleCount() < #self.rows then
        local by = last.y + last.h
        love.graphics.polygon("fill", cx - 7, by + 6, cx + 7, by + 6, cx, by + 13)
    end
end

-- The width `Theme.printTracked` will lay `text` out in. Measured here because printTracked CENTRES
-- its run inside the box it is handed, so left-aligning at x means handing it a box exactly the width
-- of the run -- and that width has to be known before the call, not returned by it.
local function trackedWidth(font, text, track)
    local tw = 0
    for i = 1, #text do
        tw = tw + font:getWidth(text:sub(i, i))
        if i < #text then tw = tw + track end
    end
    return tw
end

-- A section caption in the chrome voice, with a hairline running out to the right edge of the band.
function ForgePanel:caption(text, x, y, w)
    love.graphics.setFont(self.capFont)
    Theme.set(Theme.muted)
    text = string.upper(text)
    local tw = trackedWidth(self.capFont, text, 2)
    Theme.printTracked(text, x, y, tw, 2)
    Theme.set(Theme.hairline)
    local rx = x + tw + 10
    if x + w > rx then
        love.graphics.rectangle("fill", rx, y + self.capFont:getHeight() / 2, x + w - rx, 1)
    end
    return tw
end

function ForgePanel:drawDetail()
    local row = self:current()
    if not row then return end
    local item = row.item
    local x, w = self.detailX, self.detailW
    local y = self.boxY + CONTENT_TOP

    -- Growth is memoized per blueprint: the curve is identical at every level, so only the markers
    -- move, and those read the row's level live.
    if self.growthId ~= item.id then
        self.growth = Item.growth(item.id)
        self.growthId = item.id
    end
    local growth = self.growth
    local level = row.level or 0
    local aim = self:previewLevel() or math.min(level + 1, Item.MAX_LEVEL)

    -- --- band 1: what this is ------------------------------------------------
    self:drawIcon(item, x, y, 60)

    local hx, hw = x + 74, w - 74 - 110
    local font, name = Theme.fitText(Theme.display, item.name or "?", hw, 22, 16)
    love.graphics.setFont(font)
    Theme.set(Theme.ink)
    love.graphics.print(name, hx, y - 2)

    local bits = { row.kind == "recipe" and "recipe" or item.type }
    local disc = item.discipline and Discipline.defs[item.discipline]
        and (Discipline.displayName(item.discipline) or item.discipline)
    local class = Item.classOf(item)
    if disc then bits[#bits + 1] = disc elseif class then bits[#bits + 1] = class end
    if row.kind ~= "recipe" then bits[#bits + 1] = row.where end
    love.graphics.setFont(self.bodyFont)
    Theme.set(Theme.muted)
    love.graphics.print(Theme.ellipsize(table.concat(bits, "  ·  "), self.bodyFont, hw), hx, y + 27)

    local standing = self:standingLine(item)
    if standing then
        love.graphics.setFont(self.smallFont)
        Theme.set(Theme.cursor)
        love.graphics.print(Theme.ellipsize(standing, self.smallFont, hw), hx, y + 46)
    end

    love.graphics.setFont(self.bigFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf("+" .. level, x, y - 6, w, "right")
    love.graphics.setFont(self.capFont)
    Theme.set(Theme.muted)
    love.graphics.printf("OF " .. Item.MAX_LEVEL, x, y + 32, w, "right")

    love.graphics.setFont(self.bodyFont)
    Theme.set(Theme.ink)
    love.graphics.printf(item.description or "", x, y + 70, w, "left")

    -- --- band 2: the path ----------------------------------------------------
    local ty = y + 116
    self:caption("The path", x, ty, w)
    local ceiling = Forge.ceilingFor(self.player, item)
    self.track = ForgeTrack.layout(x, ty + 20, w, {
        level = level, ceiling = ceiling, max = Item.MAX_LEVEL,
        aim = self.aim, hover = self.hoverAim,
    })
    ForgeTrack.draw(self.track, { capFont = self.capFont, numFont = self.bodyFont })

    -- --- band 3: what the rung buys -----------------------------------------
    local py = ty + 20 + ForgeTrack.HEIGHT + 16
    local batch = aim > level + 1
    self:caption(batch and ("If forged to +" .. aim) or ("What +" .. aim .. " buys"), x, py, w)

    local rowsX, rowsW = x, w
    if growth and growth.footprint and #growth.footprint.changedAt > 1 then
        self:drawFootprintPair(growth.footprint, x, py + 20, level, aim)
        rowsX, rowsW = x + 208, w - 208
    end
    self:drawStatRows(growth, rowsX, py + 18, rowsW, level, aim, ceiling)

    if growth and #growth.flat > 0 then
        self:drawFixed(growth.flat, x, py + 128, w)
    end

    -- --- band 4: the bill ----------------------------------------------------
    local by = self.boxY + BOX_H - 130
    local cost = self:aimedCost()
    self:caption(batch and ("Total to +" .. aim) or "Cost", x, by, w)
    self:drawBill(row, cost, x, by + 20, w, batch, aim, level)
end

-- The footprint the swing lays now, and the one it would lay at the aimed rung, side by side and at
-- a size worth looking at. The old strip showed every form the item ever takes as a row of 46px
-- thumbnails; this shows the two that are actually being compared, which is the question being asked.
function ForgePanel:drawFootprintPair(footprint, x, y, level, aim)
    local function formAt(lvl)
        local at = footprint.changedAt[1]
        for _, l in ipairs(footprint.changedAt) do if l <= lvl then at = l end end
        return at
    end
    local a, b = formAt(level), formAt(aim)
    local changed = (a ~= b)
    local box = 74

    local function patch(px, lvl, accent)
        Theme.set(Theme.slot)
        love.graphics.rectangle("fill", px, y, box, box, 3, 3)
        FootprintDiagram.draw(footprint.levels[lvl], px, y, box, accent)
        Theme.set(changed and accent or Theme.hairline, changed and 0.9 or 1)
        love.graphics.rectangle("line", px + 0.5, y + 0.5, box - 1, box - 1, 3, 3)
        local f = footprint.levels[lvl]
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(accent[1], accent[2], accent[3])
        love.graphics.printf((f.shape or "?") .. " " .. (f.length or f.radius or ""),
            px, y + box + 3, box, "center")
    end

    patch(x, a, changed and Theme.muted or Colors.AOE)
    patch(x + box + 34, b, changed and MARK or Colors.AOE)

    love.graphics.setFont(self.bodyFont)
    Theme.set(changed and MARK or Theme.hairline)
    love.graphics.printf("->", x + box, y + box / 2 - self.bodyFont:getHeight() / 2, 34, "center")

    if changed then
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(UP[1], UP[2], UP[3])
        love.graphics.printf("the follow-through opens", x, y + box + 20, box * 2 + 34, "center")
    end
end

-- Each scaling stat as "now -> then", with the step it gains, over a bar spanning the stat's whole
-- floor-to-ceiling range: the filled part is what is owned, the bright part is what this climb adds,
-- and the steel tick is as far as the player's standing currently lets them go.
function ForgePanel:drawStatRows(growth, x, y, w, level, aim, ceiling)
    local stats = growth and growth.stats or {}
    if #stats == 0 then
        love.graphics.setFont(self.bodyFont)
        Theme.set(Theme.muted)
        love.graphics.print("This piece has no scaling stat to chart.", x, y + 6)
        return
    end

    local pitch, shown = 26, math.min(#stats, 4)
    for i = 1, shown do
        local s = stats[i]
        local ry = y + (i - 1) * pitch
        local from, to = s.values[level], s.values[aim]
        local delta = (from and to) and (to - from) or 0

        love.graphics.setFont(self.bodyFont)
        Theme.set(Theme.muted)
        love.graphics.print(Theme.ellipsize(s.label, self.bodyFont, 118), x, ry)

        Theme.set(Theme.ink)
        love.graphics.print(tostring(from or "-"), x + 124, ry)
        Theme.set(Theme.hairline)
        love.graphics.print("->", x + 160, ry)
        if delta > 0 then love.graphics.setColor(UP[1], UP[2], UP[3]) else Theme.set(Theme.ink) end
        love.graphics.print(tostring(to or "-"), x + 184, ry)
        love.graphics.setFont(self.smallFont)
        if delta > 0 then
            love.graphics.setColor(UP[1], UP[2], UP[3])
            love.graphics.print("+" .. delta, x + 222, ry + 3)
        end

        -- the span bar
        local bx, bw, bh = x + 262, w - 262, 7
        local span = (s.max or 0) - (s.min or 0)
        if span > 0 and bw > 20 then
            local byy = ry + 5
            Theme.set(Theme.slot)
            love.graphics.rectangle("fill", bx, byy, bw, bh, 2, 2)
            local function frac(v) return math.max(0, math.min(1, ((v or s.min) - s.min) / span)) end
            Theme.set(Theme.frame)
            love.graphics.rectangle("fill", bx, byy, bw * frac(from), bh, 2, 2)
            if delta > 0 then
                love.graphics.setColor(UP[1], UP[2], UP[3], 0.85)
                love.graphics.rectangle("fill", bx + bw * frac(from), byy,
                    bw * (frac(to) - frac(from)), bh, 2, 2)
            end
            if ceiling < Item.MAX_LEVEL then
                Theme.set(Theme.cursor, 0.9)
                love.graphics.rectangle("fill", bx + bw * frac(s.values[ceiling]) - 0.5, byy - 2, 1.5, bh + 4)
            end
            Theme.set(Theme.hairline)
            love.graphics.rectangle("line", bx, byy, bw, bh, 2, 2)
        end
    end

    if #stats > shown then
        love.graphics.setFont(self.smallFont)
        Theme.set(Theme.muted)
        love.graphics.print("+" .. (#stats - shown) .. " more", x, y + shown * pitch + 2)
    end
end

-- The magnitudes a level never moves. Item.growth has always computed these and nothing has ever
-- drawn them, so a piece's resists and its brace were invisible on the one screen about improving it.
function ForgePanel:drawFixed(flat, x, y, w)
    love.graphics.setFont(self.smallFont)
    local cx, cy = x, y
    Theme.set(Theme.muted)
    love.graphics.print("Does not change:", cx, cy + 3)
    cx = cx + self.smallFont:getWidth("Does not change:") + 10

    for _, f in ipairs(flat) do
        local text = f.label .. " " .. tostring(f.value)
        local tw = self.smallFont:getWidth(text) + 14
        if cx + tw > x + w then break end
        Theme.set(Theme.slot)
        love.graphics.rectangle("fill", cx, cy, tw, 18, 2, 2)
        Theme.set(Theme.hairline)
        love.graphics.rectangle("line", cx, cy, tw, 18, 2, 2)
        Theme.set(Theme.muted)
        love.graphics.print(text, cx + 7, cy + 3)
        cx = cx + tw + 6
    end
end

-- The bill as chips -- one per track, each going red on its own so the resource actually short is the
-- one that looks it. House stock wears a steel left edge and craft stock does not (Material.isHouse),
-- because "which family is this" is the difference between buying it and going to run a quest line.
-- Hovering a chip says where it drops (ui/material_tooltip.lua).
function ForgePanel:drawBill(row, cost, x, y, w, batch, aim, level)
    -- Both hit-test caches are rebuilt from scratch every frame. A stale rect left over from the last
    -- item selected would still answer a click after the thing it belonged to stopped being drawn.
    self.chipRects = {}
    self.forgeRect = nil

    if not cost then
        love.graphics.setFont(self.bodyFont)
        love.graphics.setColor(UP[1], UP[2], UP[3])
        love.graphics.print("At maximum level -- fully forged.", x, y + 14)
        return
    end

    local chipH = 40
    local cx = x
    local affordable = true

    local function chip(id, label, have, need, family)
        local ok = have >= need
        if not ok then affordable = false end
        local font = self.bodyFont
        local tw = math.max(font:getWidth(label), self.smallFont:getWidth(have .. " held")) + 46
        local r = { x = cx, y = y, w = tw, h = chipH, id = id }
        Theme.set(Theme.panel2)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 3, 3)
        Theme.set(ok and Theme.hairline or SHORT)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 3, 3)
        if family then
            Theme.set(family == "house" and Theme.cursor or Theme.accentAmber)
            love.graphics.rectangle("fill", r.x, r.y + 3, 2, r.h - 6)
        end
        Theme.set(Theme.slot)
        love.graphics.rectangle("fill", r.x + 8, r.y + 8, 24, 24, 2, 2)
        Theme.set(Theme.hairline)
        love.graphics.rectangle("line", r.x + 8, r.y + 8, 24, 24, 2, 2)

        love.graphics.setFont(font)
        Theme.set(Theme.ink)
        love.graphics.print(label, r.x + 38, r.y + 5)
        love.graphics.setFont(self.smallFont)
        if ok then love.graphics.setColor(UP[1], UP[2], UP[3])
        else love.graphics.setColor(SHORT[1], SHORT[2], SHORT[3]) end
        love.graphics.print(have .. " held", r.x + 38, r.y + 22)

        if id then self.chipRects[#self.chipRects + 1] = r end
        cx = cx + tw + 8
    end

    -- The currency track: technique for anything belonging to a house, gold only for classless stock --
    -- never both, so exactly one of these draws (models/forge.lua).
    if cost.technique > 0 then
        chip(nil, cost.technique .. " " .. keyLabel(cost.techniqueId),
            cost.techniqueHeld or 0, cost.technique, "money")
    else
        chip(nil, cost.gold .. " gold", self.player.gold, cost.gold, "money")
    end

    local ids = {}
    for id in pairs(cost.materials) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local def = Material.get(id)
        chip(id, cost.materials[id] .. " " .. ((def and def.name) or id),
            Player.materialCount(self.player, id), cost.materials[id],
            Material.isHouse(id) and "house" or "craft")
    end

    -- The commit. A real button, because the bench used to be worked by pressing Enter on a list row
    -- and nothing on screen ever said so.
    local bw, bh = 224, 46
    local bx = x + w - bw
    local blocked = cost.locked
    local live = affordable and not blocked
    self.forgeRect = { x = bx, y = y - 2, w = bw, h = bh }

    Theme.set(live and Theme.panel or Theme.panel2)
    love.graphics.rectangle("fill", bx, y - 2, bw, bh, 3, 3)
    love.graphics.setLineWidth(1.5)
    Theme.set(live and Theme.accentAmber or Theme.frame, live and 1 or 0.5)
    love.graphics.rectangle("line", bx, y - 2, bw, bh, 3, 3)
    love.graphics.setLineWidth(1)

    love.graphics.setFont(self.cardFont)
    Theme.set(live and Theme.accentAmber or Theme.muted, live and 1 or 0.6)
    local label = batch and ("Forge x" .. (aim - level) .. " to +" .. aim) or ("Forge to +" .. aim)
    if row.kind == "recipe" then label = "Refine to +" .. cost.level end
    love.graphics.printf(label, bx, y + 6, bw, "center")

    love.graphics.setFont(self.smallFont)
    Theme.set(Theme.muted, 0.8)
    local sub = blocked and "beyond your standing"
        or (not affordable and "short on stock")
        or (InputMode.isGamepad() and "A" or "Enter")
    love.graphics.printf(sub, bx, y + 26, bw, "center")

    if blocked then
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(SHORT[1], SHORT[2], SHORT[3])
        love.graphics.printf(self:ceilingReason(row.item), x, y + chipH + 8, w - bw - 12, "left")
    end
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

function ForgePanel:mousemoved(x, y)
    self.mx, self.my = x, y
    self.closeButton:mousemoved(x, y)

    -- Hover moves the selection, so all three input paths stay in sync.
    if self:hasRows() then
        for i = 1, #self.rows do
            if pointIn(self:cardRect(i), x, y) then
                if self.sel ~= i then
                    self.sel = i
                    Sound.play("ui.move")
                    self:resetAim()
                end
                break
            end
        end
    end

    -- Pointing at a rung previews it; leaving the track drops back to the picked one.
    self:setHoverAim(self.track and ForgeTrack.hit(self.track, x, y) or nil)

    self.hoverMaterial = nil
    for _, r in ipairs(self.chipRects or {}) do
        if pointIn(r, x, y) then self.hoverMaterial = r.id break end
    end
end

function ForgePanel:cursorKind(x, y)
    if self.closeButton:contains(x, y) then return "hand" end
    for _, m in ipairs(MODES) do
        if pointIn(self.segRects[m], x, y) then return "hand" end
    end
    if pointIn(self.forgeRect, x, y) then return "hand" end
    if self.track and ForgeTrack.hit(self.track, x, y) then return "hand" end
    if self:hasRows() then
        for i = 1, #self.rows do
            if pointIn(self:cardRect(i), x, y) then return "hand" end
        end
    end
    return "arrow"
end

function ForgePanel:wheelmoved(dx, dy)
    self:scrollBy(-dy)
end

function ForgePanel:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then self:close() return end
    for _, m in ipairs(MODES) do
        if pointIn(self.segRects[m], x, y) then self:setMode(m) return end
    end
    if self:hasRows() then
        if pointIn(self.forgeRect, x, y) then
            Sound.play("ui.confirm")
            self:commit()
            return
        end
        local lvl = self.track and ForgeTrack.hit(self.track, x, y)
        if lvl then self:setAim(lvl) return end
        for i = 1, #self.rows do
            if pointIn(self:cardRect(i), x, y) then
                self.sel = i
                self:resetAim()
                return
            end
        end
    end
    if not pointIn({ x = self.boxX, y = self.boxY, w = BOX_W, h = BOX_H }, x, y) then self:close() end
end

function ForgePanel:keypressed(key)
    if key == "escape" then self:close()
    elseif key == "tab" then self:cycleMode(1)
    elseif key == "up" or key == "w" then self:moveSelection(-1)
    elseif key == "down" or key == "s" then self:moveSelection(1)
    elseif key == "pageup" then self:moveSelection(-self:visibleCount())
    elseif key == "pagedown" then self:moveSelection(self:visibleCount())
    elseif key == "left" or key == "a" then self:nudgeAim(-1)
    elseif key == "right" or key == "d" then self:nudgeAim(1)
    elseif key == "return" or key == "kpenter" or key == "space" then
        Sound.play("ui.confirm")
        self:commit()
    end
end

function ForgePanel:gamepadpressed(joystick, button)
    if button == "b" then self:close()
    elseif button == "leftshoulder" then self:cycleMode(-1)
    elseif button == "rightshoulder" then self:cycleMode(1)
    elseif button == "dpup" then self:moveSelection(-1)
    elseif button == "dpdown" then self:moveSelection(1)
    elseif button == "dpleft" then self:nudgeAim(-1)
    elseif button == "dpright" then self:nudgeAim(1)
    elseif button == "a" or button == "start" then
        Sound.play("ui.confirm")
        self:commit()
    end
end

return ForgePanel
