-- The MOCK BATTLE SETUP: a debug-only modal the main menu opens in front of the Mock Battle, so the far
-- side of the practice board is chosen rather than hard-coded. Three decisions, one column each:
--
--   Ground    -- which biome the board is rolled for (data/biomes/), plus the DEPTH the far side is
--                minted at (the same floor number a descent fights at, Descent.dangerLevel).
--   Encounter -- "Custom", or any authored fight (data/encounters/ of kind combat/elite). Encounters
--                that belong to the chosen ground list first; the rest follow, marked off-ground, since
--                fighting the wood's wolves on castle stone is still a useful thing to look at.
--   Enemies   -- for an encounter, the composition it ROLLED for this ground and depth, which is the
--                exact list the fight will seat (handed over as `encounter.composition`, the override
--                EncounterBattle.spec already honours) -- so what is previewed here is what you meet.
--                For Custom, a roster you build from the whole character catalog, type-to-search.
--
-- The panel only decides; the caller launches. `onStart(config)` receives
--   { biome, depth, encounterId?, composition = { ids... } }
-- and `onClose()` fires on Esc / B / the close button. The last configuration is kept at module level
-- so a debug loop of "fight, back to menu, fight again" reopens where it left off.
--
-- Three-input + mouse-only, per the project standard: every row is clickable and the wheel scrolls the
-- list under the pointer; Left/Right (D-pad) walk the columns, Up/Down walk a column, Enter/A picks.
-- Depth is -/+ (LB/RB). Start is its own button, Enter on it, or the pad's Start from anywhere.

local CloseButton = require("ui.close_button")
local InputMode = require("input_mode")
local Scale = require("scale")
local Theme = require("ui.theme")

local Arena = require("models.arena")
local Character = require("models.character")
local Encounter = require("models.encounter")
local Growth = require("models.growth")
local Registry = require("models.registry")

local MockSetup = {}
MockSetup.__index = MockSetup

local BOX_W, BOX_H = 1120, 640
local PAD = 20
local ROW_H = 24
local HEAD_H = 30 -- a column's caption band
local GROUND_W = 200
local ENC_W = 320
local FOOT_H = 56
local DEPTH_MIN, DEPTH_MAX = 1, 15

-- The Custom roster's ceiling: a mock is objective-kind with no quest behind it, so Arena.enemyCap
-- answers the default tier and would silently drop anything past it. Refusing the add says so instead.
local ROSTER_MAX = Arena.DEFAULT_ENEMY_CAP

-- What the panel last held, so reopening it resumes the setup rather than resetting it.
local remembered = { biome = "castle", depth = 3, encounterId = nil, roster = {} }

local function inRect(r, x, y) return r and x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h end

local function charName(id)
    local def = Character.defs[id]
    return (def and def.name) or id
end

-- The level `id` is minted at on this floor -- the same call Growth.spawn makes, so the row says what
-- the fight will field (ordinary stock lags the danger level; a named body tracks it).
local function spawnLevel(id, depth)
    local danger = require("models.descent").dangerLevel({ floor = depth })
    return Growth.combatantLevel(Character.defs[id], danger, nil)
end

-- ---------------------------------------------------------------------------
-- A scrolling list: rows + cursor + scroll, laid into a rect. Rows are { label, sub?, muted?, value }.
-- ---------------------------------------------------------------------------

local List = {}
List.__index = List

local function newList(rect)
    return setmetatable({ rows = {}, cursor = 1, scroll = 0, rect = rect }, List)
end

function List:visible() return math.max(1, math.floor(self.rect.h / ROW_H)) end

function List:setRows(rows)
    self.rows = rows
    self.cursor = math.max(1, math.min(self.cursor, #rows))
    self:clampScroll()
end

function List:clampScroll()
    local vis = self:visible()
    if self.cursor > self.scroll + vis then self.scroll = self.cursor - vis end
    if self.cursor <= self.scroll then self.scroll = self.cursor - 1 end
    self.scroll = math.max(0, math.min(self.scroll, math.max(0, #self.rows - vis)))
end

function List:move(d)
    if #self.rows == 0 then return end
    self.cursor = ((self.cursor - 1 + d) % #self.rows) + 1
    self:clampScroll()
end

function List:wheel(dy)
    local vis = self:visible()
    self.scroll = math.max(0, math.min(self.scroll - dy * 3, math.max(0, #self.rows - vis)))
end

-- The row index under (x, y), or nil.
function List:rowAt(x, y)
    if not inRect(self.rect, x, y) then return nil end
    local i = self.scroll + math.floor((y - self.rect.y) / ROW_H) + 1
    return self.rows[i] and i or nil
end

function List:current() return self.rows[self.cursor] end

-- `selected(row)` marks the committed pick (amber); the cursor ring shows only while `focused`.
function List:draw(font, focused, selected)
    local r = self.rect
    Theme.fill(Theme.slot, r.x, r.y, r.w, r.h)
    love.graphics.setScissor(r.x, r.y, r.w, r.h)
    love.graphics.setFont(font)
    local vis = self:visible()
    for i = self.scroll + 1, math.min(#self.rows, self.scroll + vis) do
        local row = self.rows[i]
        local y = r.y + (i - self.scroll - 1) * ROW_H
        local isSel = selected and selected(row)
        if isSel then
            Theme.set(Theme.accentAmber, 0.16)
            love.graphics.rectangle("fill", r.x + 1, y + 1, r.w - 2, ROW_H - 2, 2, 2)
        end
        if focused and i == self.cursor then
            Theme.set(Theme.cursor)
            love.graphics.rectangle("line", r.x + 1.5, y + 1.5, r.w - 3, ROW_H - 3, 2, 2)
        end
        Theme.set(isSel and Theme.accentAmber or (row.muted and Theme.muted or Theme.ink), row.muted and 0.7 or 1)
        local textY = y + (ROW_H - font:getHeight()) / 2
        local subW = row.sub and (font:getWidth(row.sub) + 12) or 0
        love.graphics.print(Theme.ellipsize(row.label, font, r.w - 16 - subW), r.x + 8, textY)
        if row.sub then
            Theme.set(Theme.muted, 0.8)
            love.graphics.print(row.sub, r.x + r.w - 8 - font:getWidth(row.sub), textY)
        end
    end
    love.graphics.setScissor()
    if #self.rows > vis then
        -- A thin scroll thumb, so a long catalog says how long it is.
        local trackH = r.h - 4
        local thumbH = math.max(16, trackH * vis / #self.rows)
        local thumbY = r.y + 2 + (trackH - thumbH) * (self.scroll / (#self.rows - vis))
        Theme.set(Theme.frame, 0.7)
        love.graphics.rectangle("fill", r.x + r.w - 4, thumbY, 3, thumbH)
    end
    Theme.set(Theme.hairline)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 2, 2)
end

-- ---------------------------------------------------------------------------
-- The panel
-- ---------------------------------------------------------------------------

-- Every authored fight a mock can seat: combat or elite with a composition. Packs are left out -- their
-- company is drawn when a party falls (Descent.packGuard) and a blueprint alone has none to show.
local function fightEncounters()
    local ids = {}
    for id, def in pairs(Encounter.defs) do
        if (def.kind == "combat" or def.kind == "elite") and def.composition and not def.parked then
            ids[#ids + 1] = id
        end
    end
    table.sort(ids)
    return ids
end

local function belongsTo(def, biome, depth)
    if not def.condition then return true end
    local ok, yes = pcall(def.condition, { biome = biome, depth = depth, prestige = depth })
    return ok and yes and true or false
end

function MockSetup.new(opts)
    opts = opts or {}
    local self = setmetatable({}, MockSetup)
    self.onStart = opts.onStart
    self.onClose = opts.onClose

    self.titleFont = Theme.display(26)
    self.headFont = Theme.display(17)
    self.rowFont = Theme.body(15)
    self.hintFont = Theme.body(13)

    self.bx = math.floor(Scale.WIDTH / 2 - BOX_W / 2)
    self.by = math.floor(Scale.HEIGHT / 2 - BOX_H / 2)
    self.closeButton = CloseButton.new(self.bx + BOX_W, self.by)

    self.biome = remembered.biome
    self.depth = remembered.depth
    self.encounterId = remembered.encounterId
    self.roster = {}
    for i, id in ipairs(remembered.roster) do self.roster[i] = id end
    self.search = ""
    self.notice = nil

    -- Geometry. Columns sit under a shared caption line; the footer holds depth-free controls.
    local top = self.by + 58 + HEAD_H
    local bodyH = BOX_H - 58 - HEAD_H - FOOT_H - 10
    local x1 = self.bx + PAD
    local x2 = x1 + GROUND_W + PAD
    local x3 = x2 + ENC_W + PAD
    local w3 = self.bx + BOX_W - PAD - x3
    self.cols = { ground = x1, encounter = x2, enemies = x3, enemiesW = w3, top = top }

    -- Ground: the biome list, and the depth stepper under it.
    local Biomes = Registry.load("data/biomes", "data.biomes")
    local biomeRows = {}
    for id, def in pairs(Biomes) do biomeRows[#biomeRows + 1] = { label = def.name or id, sub = id, value = id } end
    table.sort(biomeRows, function(a, b) return a.value < b.value end)
    self.biomeList = newList({ x = x1, y = top, w = GROUND_W, h = #biomeRows * ROW_H })
    self.biomeList:setRows(biomeRows)
    for i, row in ipairs(biomeRows) do if row.value == self.biome then self.biomeList.cursor = i end end
    local dy = top + #biomeRows * ROW_H + 34
    self.depthY = dy
    self.depthMinus = { x = x1, y = dy, w = 34, h = 30 }
    self.depthPlus = { x = x1 + GROUND_W - 34, y = dy, w = 34, h = 30 }

    self.encList = newList({ x = x2, y = top, w = ENC_W, h = math.floor(bodyH / ROW_H) * ROW_H })

    -- Enemies. Custom mode splits the column: the roster being built on the left, the catalog on the right.
    local rosterW = math.floor((w3 - PAD) * 0.42)
    local catW = w3 - PAD - rosterW
    self.rosterList = newList({ x = x3, y = top, w = rosterW, h = ROSTER_MAX * ROW_H })
    self.catRect = { x = x3 + rosterW + PAD, w = catW }
    self.searchRect = { x = self.catRect.x, y = top, w = catW, h = 26 }
    self.catList = newList({ x = self.catRect.x, y = top + 32, w = catW,
        h = math.floor((bodyH - 32) / ROW_H) * ROW_H })
    self.previewList = newList({ x = x3, y = top, w = w3, h = math.floor((bodyH - 40) / ROW_H) * ROW_H })
    self.rerollRect = { x = x3, y = top + self.previewList.rect.h + 8, w = 120, h = 30 }

    local fy = self.by + BOX_H - FOOT_H + 10
    self.startRect = { x = self.bx + BOX_W - PAD - 180, y = fy, w = 180, h = 38 }

    self.catIds = {}
    for id in pairs(Character.defs) do self.catIds[#self.catIds + 1] = id end
    table.sort(self.catIds, function(a, b)
        local na, nb = charName(a):lower(), charName(b):lower()
        if na ~= nb then return na < nb end
        return a < b
    end)

    self:rebuildEncounters()
    self:rebuildCatalog()
    self:rebuildRoster()
    self.zone = "encounter"
    return self
end

function MockSetup:isCustom() return self.encounterId == nil end

-- Which columns keyboard/pad focus walks across, left to right, in the current mode.
function MockSetup:zones()
    if self:isCustom() then return { "ground", "encounter", "roster", "catalog", "start" } end
    return { "ground", "encounter", "preview", "start" }
end

function MockSetup:rebuildEncounters()
    local home, away = {}, {}
    for _, id in ipairs(fightEncounters()) do
        local def = Encounter.defs[id]
        local row = { label = def.name or id, sub = def.kind, value = id }
        if belongsTo(def, self.biome, self.depth) then
            home[#home + 1] = row
        else
            row.muted = true
            row.sub = def.kind .. " - off-ground"
            away[#away + 1] = row
        end
    end
    local rows = { { label = "Custom", sub = "pick bodies", value = false } }
    for _, r in ipairs(home) do rows[#rows + 1] = r end
    for _, r in ipairs(away) do rows[#rows + 1] = r end
    self.encList:setRows(rows)
    for i, row in ipairs(rows) do
        if (row.value or nil) == self.encounterId then self.encList.cursor = i end
    end
    self.encList:clampScroll()
    self:rollPreview()
end

-- Roll the chosen encounter's composition for this ground and depth -- the list the fight will seat.
function MockSetup:rollPreview()
    self.preview = {}
    self.previewError = nil
    local def = self.encounterId and Encounter.defs[self.encounterId]
    if not def then self.previewList:setRows({}); return end
    local ctx = { depth = self.depth, rung = def.rung, biome = self.biome, encounterKind = def.kind,
        prestige = self.depth }
    local ok, ids = pcall(Arena.resolveComposition, def.composition, ctx)
    if not ok then
        self.previewError = tostring(ids)
        ids = {}
    end
    local cap = Arena.enemyCap(ctx)
    local rows = {}
    for i, id in ipairs(ids or {}) do
        self.preview[i] = id
        rows[#rows + 1] = { label = charName(id), sub = "Lv " .. spawnLevel(id, self.depth) .. "  " .. id,
            value = id, muted = cap and i > cap or nil }
    end
    self.previewCap = cap
    self.previewList:setRows(rows)
end

function MockSetup:rebuildCatalog()
    local q = self.search:lower()
    local rows = {}
    for _, id in ipairs(self.catIds) do
        local name = charName(id)
        if q == "" or name:lower():find(q, 1, true) or id:lower():find(q, 1, true) then
            rows[#rows + 1] = { label = name, sub = id:gsub("^character_", ""), value = id }
        end
    end
    self.catList:setRows(rows)
end

function MockSetup:rebuildRoster()
    local rows = {}
    for i, id in ipairs(self.roster) do
        rows[i] = { label = charName(id), sub = "Lv " .. spawnLevel(id, self.depth), value = i }
    end
    self.rosterList:setRows(rows)
end

function MockSetup:remember()
    remembered.biome = self.biome
    remembered.depth = self.depth
    remembered.encounterId = self.encounterId
    remembered.roster = {}
    for i, id in ipairs(self.roster) do remembered.roster[i] = id end
end

function MockSetup:say(text) self.notice = text; self.noticeTimer = 3 end

-- ---- actions ----

function MockSetup:pickBiome(i)
    local row = self.biomeList.rows[i]
    if not row then return end
    self.biomeList.cursor = i
    self.biome = row.value
    self:rebuildEncounters()
end

function MockSetup:setDepth(d)
    local nd = math.max(DEPTH_MIN, math.min(DEPTH_MAX, d))
    if nd == self.depth then return end
    self.depth = nd
    self:rebuildEncounters()
    self:rebuildRoster()
end

function MockSetup:pickEncounter(i)
    local row = self.encList.rows[i]
    if not row then return end
    self.encList.cursor = i
    self.encounterId = row.value or nil
    self:rollPreview()
end

function MockSetup:addBody(i)
    local row = self.catList.rows[i]
    if not row then return end
    self.catList.cursor = i
    if #self.roster >= ROSTER_MAX then
        self:say("The board seats " .. ROSTER_MAX .. " at most")
        return
    end
    self.roster[#self.roster + 1] = row.value
    self:rebuildRoster()
    self.rosterList.cursor = #self.roster
    self.rosterList:clampScroll()
end

function MockSetup:removeBody(i)
    if not self.roster[i] then return end
    table.remove(self.roster, i)
    self:rebuildRoster()
end

function MockSetup:start()
    local comp
    if self:isCustom() then
        if #self.roster == 0 then self:say("Add at least one enemy"); return end
        comp = {}
        for i, id in ipairs(self.roster) do comp[i] = id end
    else
        if #self.preview == 0 then self:say("That encounter rolled nobody here"); return end
        comp = {}
        for i, id in ipairs(self.preview) do comp[i] = id end
    end
    self:remember()
    if self.onStart then
        self.onStart({ biome = self.biome, depth = self.depth, encounterId = self.encounterId,
            composition = comp })
    end
end

function MockSetup:close()
    self:remember()
    if self.onClose then self.onClose() end
end

-- ---- update / draw ----

function MockSetup:update(dt)
    if self.noticeTimer then
        self.noticeTimer = self.noticeTimer - dt
        if self.noticeTimer <= 0 then self.notice, self.noticeTimer = nil, nil end
    end
end

local function button(rect, label, font, focused, enabled)
    Theme.fill(focused and Theme.panel2 or Theme.slot, rect.x, rect.y, rect.w, rect.h)
    Theme.set(focused and Theme.cursor or Theme.frame, enabled == false and 0.4 or 1)
    love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 3, 3)
    love.graphics.setFont(font)
    Theme.set(Theme.ink, enabled == false and 0.45 or 1)
    love.graphics.printf(label, rect.x, rect.y + (rect.h - font:getHeight()) / 2, rect.w, "center")
end

function MockSetup:caption(text, x, w, right)
    love.graphics.setFont(self.headFont)
    Theme.set(Theme.accentAmber)
    love.graphics.print(text, x, self.cols.top - HEAD_H + 4)
    if right then
        love.graphics.setFont(self.hintFont)
        Theme.set(Theme.muted)
        love.graphics.printf(right, x, self.cols.top - HEAD_H + 8, w, "right")
    end
end

function MockSetup:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)
    Theme.plate(self.bx, self.by, BOX_W, BOX_H, Theme.R)

    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf("Mock Battle", self.bx, self.by + 14, BOX_W, "center")

    local c = self.cols
    local z = self.zone

    -- Ground
    self:caption("Ground", c.ground, GROUND_W)
    self.biomeList:draw(self.rowFont, z == "ground", function(row) return row.value == self.biome end)
    love.graphics.setFont(self.headFont)
    Theme.set(Theme.accentAmber)
    love.graphics.print("Depth", c.ground, self.depthY - 26)
    button(self.depthMinus, "-", self.headFont, false, self.depth > DEPTH_MIN)
    button(self.depthPlus, "+", self.headFont, false, self.depth < DEPTH_MAX)
    love.graphics.setFont(self.headFont)
    Theme.set(Theme.ink)
    love.graphics.printf("Floor " .. self.depth, c.ground, self.depthY + 5, GROUND_W, "center")
    love.graphics.setFont(self.hintFont)
    Theme.set(Theme.muted)
    local lvl = require("models.descent").dangerLevel({ floor = self.depth })
    love.graphics.printf("danger level " .. tostring(lvl), c.ground, self.depthY + 36, GROUND_W, "center")

    -- Encounter
    self:caption("Encounter", c.encounter, ENC_W)
    self.encList:draw(self.rowFont, z == "encounter", function(row) return (row.value or nil) == self.encounterId end)

    -- Enemies
    if self:isCustom() then
        local rw = self.rosterList.rect.w
        self:caption("Roster", c.enemies, rw, #self.roster .. " / " .. ROSTER_MAX)
        self.rosterList:draw(self.rowFont, z == "roster")
        if #self.roster == 0 then
            love.graphics.setFont(self.hintFont)
            Theme.set(Theme.muted)
            love.graphics.printf("Pick bodies from the catalog; click one here to remove it",
                c.enemies + 8, c.top + 6, rw - 16, "left")
        end
        self:caption("Catalog", self.catRect.x, self.catRect.w, #self.catList.rows .. " bodies")
        local sr = self.searchRect
        Theme.fill(Theme.slot, sr.x, sr.y, sr.w, sr.h)
        Theme.set(z == "catalog" and Theme.cursor or Theme.hairline)
        love.graphics.rectangle("line", sr.x, sr.y, sr.w, sr.h, 2, 2)
        love.graphics.setFont(self.rowFont)
        if self.search == "" then
            Theme.set(Theme.muted, 0.6)
            love.graphics.print("type to search", sr.x + 8, sr.y + 4)
        else
            Theme.set(Theme.ink)
            love.graphics.print("/" .. self.search, sr.x + 8, sr.y + 4)
        end
        self.catList:draw(self.rowFont, z == "catalog")
    else
        local cap = self.previewCap
        self:caption("Enemies", c.enemies, c.enemiesW,
            #self.preview .. (cap and (" rolled, board seats " .. cap) or " rolled"))
        self.previewList:draw(self.rowFont, z == "preview")
        if self.previewError then
            love.graphics.setFont(self.hintFont)
            Theme.set(Theme.accentWeapon)
            love.graphics.printf("composition failed: " .. self.previewError, c.enemies + 8, c.top + 6,
                c.enemiesW - 16, "left")
        end
        button(self.rerollRect, "Reroll", self.rowFont, z == "preview")
    end

    -- Footer
    button(self.startRect, "Start", self.headFont, z == "start")
    love.graphics.setFont(self.hintFont)
    local hint
    if InputMode.isGamepad() then
        hint = "D-pad move  -  A pick  -  LB/RB depth  -  X reroll  -  Start fight  -  B leave"
    elseif not InputMode.touch then
        hint = "Arrows move  -  Enter pick  -  -/+ depth  -  F5 fight  -  Esc leave"
            .. (self:isCustom() and "  -  type to search" or "")
    end
    if self.notice then
        Theme.set(Theme.accentWeapon)
        love.graphics.print(self.notice, self.bx + PAD, self.startRect.y + 11)
    elseif hint then
        Theme.set(Theme.muted)
        love.graphics.print(hint, self.bx + PAD, self.startRect.y + 11)
    end

    self.closeButton:draw()
    love.graphics.setColor(1, 1, 1)
end

-- ---- input ----

-- The list and the zone name under the pointer, or nil.
function MockSetup:listAt(x, y)
    if inRect(self.biomeList.rect, x, y) then return self.biomeList, "ground" end
    if inRect(self.encList.rect, x, y) then return self.encList, "encounter" end
    if self:isCustom() then
        if inRect(self.rosterList.rect, x, y) then return self.rosterList, "roster" end
        if inRect(self.catList.rect, x, y) then return self.catList, "catalog" end
    elseif inRect(self.previewList.rect, x, y) then
        return self.previewList, "preview"
    end
end

-- Hover moves the CURSOR within a list only (a pick is a click), so the keyboard resumes from where
-- the pointer left it without the hover ever committing anything.
function MockSetup:mousemoved(x, y)
    self.closeButton:mousemoved(x, y)
    local list, zone = self:listAt(x, y)
    if list then
        local i = list:rowAt(x, y)
        if i then list.cursor = i; self.zone = zone end
    elseif inRect(self.startRect, x, y) then
        self.zone = "start"
    end
end

function MockSetup:cursorKind(x, y)
    if self.closeButton:contains(x, y) then return "hand" end
    local list = self:listAt(x, y)
    if list and list:rowAt(x, y) then return "hand" end
    if inRect(self.startRect, x, y) or inRect(self.depthMinus, x, y) or inRect(self.depthPlus, x, y) then
        return "hand"
    end
    if not self:isCustom() and inRect(self.rerollRect, x, y) then return "hand" end
    return "arrow"
end

function MockSetup:activate(zone, i)
    if zone == "ground" then self:pickBiome(i)
    elseif zone == "encounter" then self:pickEncounter(i)
    elseif zone == "roster" then self:removeBody(i)
    elseif zone == "catalog" then self:addBody(i)
    elseif zone == "preview" then self:rollPreview()
    elseif zone == "start" then self:start() end
end

function MockSetup:mousepressed(x, y, button)
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then self:close(); return end
    if inRect(self.depthMinus, x, y) then self:setDepth(self.depth - 1); return end
    if inRect(self.depthPlus, x, y) then self:setDepth(self.depth + 1); return end
    if inRect(self.startRect, x, y) then self:start(); return end
    if not self:isCustom() and inRect(self.rerollRect, x, y) then self:rollPreview(); return end
    local list, zone = self:listAt(x, y)
    local i = list and list:rowAt(x, y)
    if i then
        self.zone = zone
        self:activate(zone, i)
    end
end

function MockSetup:wheelmoved(_, dy)
    local mx, my = Scale.toGame(love.mouse.getPosition())
    local list = self:listAt(mx, my)
    ;(list or self:focusedList() or self.encList):wheel(dy)
end

function MockSetup:focusedList()
    return ({ ground = self.biomeList, encounter = self.encList, roster = self.rosterList,
        catalog = self.catList, preview = self.previewList })[self.zone]
end

function MockSetup:stepZone(d)
    local zs = self:zones()
    local at = 1
    for i, z in ipairs(zs) do if z == self.zone then at = i end end
    at = math.max(1, math.min(#zs, at + d))
    self.zone = zs[at]
end

function MockSetup:confirm()
    local list = self:focusedList()
    self:activate(self.zone, list and list.cursor or 1)
end

function MockSetup:keypressed(key)
    if key == "escape" then
        if self.search ~= "" then self.search = ""; self:rebuildCatalog(); return end
        self:close()
    elseif key == "backspace" then
        if self:isCustom() and self.search ~= "" then
            self.search = self.search:sub(1, -2)
            self:rebuildCatalog()
        elseif self.zone == "roster" then
            self:removeBody(self.rosterList.cursor)
        end
    elseif key == "left" then self:stepZone(-1)
    elseif key == "right" then self:stepZone(1)
    elseif key == "up" then local l = self:focusedList(); if l then l:move(-1) end
    elseif key == "down" then local l = self:focusedList(); if l then l:move(1) end
    elseif key == "pageup" then local l = self:focusedList(); if l then l:move(-l:visible()) end
    elseif key == "pagedown" then local l = self:focusedList(); if l then l:move(l:visible()) end
    elseif key == "-" or key == "kp-" then self:setDepth(self.depth - 1)
    elseif key == "=" or key == "+" or key == "kp+" then self:setDepth(self.depth + 1)
    elseif key == "f5" then self:start()
    elseif key == "return" or key == "kpenter" then self:confirm()
    end
end

-- Type-to-search, in Custom mode only: letters, digits, space and underscore narrow the catalog, and
-- focus jumps to it so Enter adds the top match.
function MockSetup:textinput(t)
    if not self:isCustom() then return end
    if not t:match("^[%w _]$") then return end
    self.search = self.search .. t:lower()
    self:rebuildCatalog()
    self.catList.cursor = 1
    self.catList.scroll = 0
    self.zone = "catalog"
end

function MockSetup:gamepadpressed(_, btn)
    if btn == "b" then self:close()
    elseif btn == "dpleft" then self:stepZone(-1)
    elseif btn == "dpright" then self:stepZone(1)
    elseif btn == "dpup" then local l = self:focusedList(); if l then l:move(-1) end
    elseif btn == "dpdown" then local l = self:focusedList(); if l then l:move(1) end
    elseif btn == "leftshoulder" then self:setDepth(self.depth - 1)
    elseif btn == "rightshoulder" then self:setDepth(self.depth + 1)
    elseif btn == "x" then if not self:isCustom() then self:rollPreview() end
    elseif btn == "start" then self:start()
    elseif btn == "a" then self:confirm()
    end
end

return MockSetup
