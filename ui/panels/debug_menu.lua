-- The battle debug context menu: a cursor-anchored dropdown that pops up on RIGHT-CLICK during a
-- battle, in development builds only (states/battle.lua gates its creation on Debug.enabled, exactly
-- as it gates the Win/Lose buttons). Right-click a tile and the menu reads the tile under the cursor:
--   * a living unit there -> the unit page (damage, kill, heal, statuses, items, initiative, control,
--     extra action, invulnerable, gold, clone, remove, move-to-tile)
--   * empty ground        -> the terrain page (summon, place hazard/trap/prop, change terrain)
--
-- It is a navigable PAGE STACK rather than a single control: a submenu row pushes a page, right-click
-- / Esc / Backspace / B pops one, and popping the root closes. Long lists (every status, the whole
-- character and item catalogs) scroll a fixed viewport window and can be TYPE-TO-SEARCH filtered:
-- typing letters on any list page narrows it by a case-insensitive substring on the row label (shown
-- as `/query` in the header); Backspace edits the query and Esc clears it before it backs out.
-- The Items pages (Inspect / Give item / Remove item) name items rather than commands, so the
-- cursored row floats the game's normal item tooltip beside the box -- see DebugMenu:drawItemTooltip.
-- Every action calls the underlying
-- Combat / Status / Hazard / ... model function directly -- the `fx.*` layer is per-cast state that
-- only exists inside resolveCast, so a debug tool that pokes the board out-of-turn must not use it.
--
-- Three-input + mouse-only by construction, mirroring ui/panels/windup_chooser.lua: click a row or a
-- stepper control; arrows/Enter/Backspace on a keyboard; D-pad/A/B on a pad; right-click or a click
-- off the box backs out. ASCII glyphs only (">", "-", "+", "Apply") so nothing renders as tofu if a
-- face lacks the fancy arrows.
local Theme = require("ui.theme")
local Scale = require("scale")

local Combat = require("models.combat")
local Status = require("models.status")
local Character = require("models.character")
local Item = require("models.item")
local Trait = require("models.trait")
local Hazard = require("models.hazard")
local Trap = require("models.trap")
local Prop = require("models.prop")
local Arena = require("models.arena")
local ItemTooltip = require("ui.item_tooltip")

local DebugMenu = {}
DebugMenu.__index = DebugMenu

local MENU_W = 196
local ROW_H = 22
local HEADER_H = 20
local PAD = 6
local MAX_ROWS = 12 -- visible list rows before the window scrolls
local FONT_SIZE = 14

-- ids of a `.defs` registry (Registry.load table), sorted for a stable, scannable list.
local function sortedIds(defs)
    local ids = {}
    for id in pairs(defs or {}) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
end

local function pointIn(r, x, y)
    return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

-- A list page: a column of selectable rows. Each row is { label, kind, build|act }, where kind is
-- "submenu" (build() returns the page to push), "action" (act() mutates, then the menu closes) or
-- "info" (inert, read-only). `search` is the live type-to-filter string; `filtered` caches the
-- matching subset (nil when the filter is empty and all rows show) -- see DebugMenu:applyFilter.
local function listPage(title, rows)
    return { kind = "list", title = title, rows = rows, cursor = 1, scroll = 0, search = "" }
end

-- The rows a list page currently shows: the filtered subset while a search is active, else every row.
local function viewRows(page)
    return page.filtered or page.rows
end

-- A stepper page: one integer value with -/+ arrows, preset buttons and Apply. opts:
--   value/min/max/step, presets (list of ints), apply(value).
--   presetAdds -- when true a preset button ADDS its amount to the running value (clamped) instead of
--   replacing it; used by "Add gold", so tapping 100 then 50 dials 150, and Apply grants the total.
local function stepperPage(title, opts)
    return {
        kind = "stepper", title = title,
        value = opts.value or 0, min = opts.min or 0, max = opts.max or 999, step = opts.step or 1,
        presets = opts.presets or {}, apply = opts.apply, presetAdds = opts.presetAdds,
    }
end

-- opts:
--   x, y         the cursor position the menu drops from (its top-left, clamped on-screen)
--   combat       battle.combat
--   tile         { x, y } the right-clicked cell (always set)
--   unit         the living unit on that cell, or nil for the terrain menu
--   onClose      fn() -- clear battle.debugMenu
--   onPickTile   fn(fn(tx,ty)) -- close and arm board-targeting; the next left-click feeds tx,ty
--   refresh      fn() -- called after any mutation so the host re-derives the board/turn strip/tooltips
function DebugMenu.new(opts)
    opts = opts or {}
    local self = setmetatable({}, DebugMenu)
    self.combat = opts.combat
    self.unit = opts.unit
    self.tile = opts.tile or { x = 1, y = 1 }
    self.onClose = opts.onClose or function() end
    self.onPickTile = opts.onPickTile
    self.refresh = opts.refresh or function() end
    self.font = Theme.body(FONT_SIZE)
    self.ax = opts.x or Scale.WIDTH / 2
    self.ay = opts.y or Scale.HEIGHT / 2
    self.closed = false

    local combat, u, tile, menu = self.combat, self.unit, self.tile, self

    -- ---- builders (each returns a page) ---------------------------------------------------------
    local function damagePage()
        return stepperPage("Damage", { value = 10, min = 1, max = 999, step = 1, presets = { 5, 10, 25, 50 },
            apply = function(v)
                Combat.dealFlatDamage(combat, u, v, { "physical" }, nil, nil, { raw = true })
            end })
    end

    local function killPage()
        local function lethal(deny)
            local hp = (u.char and u.char.stats.health and u.char.stats.health.current) or 9999
            Combat.dealFlatDamage(combat, u, hp + 9999, { "physical" }, nil, nil, { raw = true, denyRevival = deny })
        end
        return listPage("Kill", {
            { label = "Down (revivable)", kind = "action", act = function() lethal(false) end },
            { label = "Kill to corpse", kind = "action", act = function() lethal(true) end },
        })
    end

    local function healPage()
        local res = u.char and u.char.stats.health
        local maxhp = (type(res) == "table" and res.max) or 100
        return listPage("Heal / HP", {
            { label = "Heal to full", kind = "action", act = function() Combat.applyHeal(combat, u, 99999) end },
            { label = "Set HP", kind = "submenu", build = function()
                return stepperPage("Set HP", {
                    value = (type(res) == "table" and res.current) or maxhp, min = 1, max = maxhp, step = 1,
                    presets = { 1, math.max(1, math.floor(maxhp / 4)), math.max(1, math.floor(maxhp / 2)), maxhp },
                    apply = function(v)
                        if type(res) == "table" then res.current = math.max(1, math.min(maxhp, v)) end
                    end,
                })
            end },
        })
    end

    local function applyStatusPage()
        local rows = {}
        for _, id in ipairs(sortedIds(Status.defs)) do
            local def = Status.defs[id]
            rows[#rows + 1] = { label = def.name or id, kind = "submenu", build = function()
                return stepperPage("Duration", {
                    value = def.duration or Status.TICKS_PER_TURN, min = 1, max = 99, step = 1,
                    presets = { 5, 10, 15, 25 },
                    apply = function(v) Status.apply(combat, u, id, { duration = v }) end,
                })
            end }
        end
        return listPage("Apply status", rows)
    end

    local function removeStatusPage()
        local rows = { { label = "Cleanse all", kind = "action", act = function() Combat.cleanse(combat, u) end } }
        for _, s in ipairs(u.statuses or {}) do
            local def = Status.defs[s.id]
            rows[#rows + 1] = { label = (def and def.name) or s.id, kind = "action",
                act = function() Status.remove(combat, u, s.id) end }
        end
        return listPage("Remove status", rows)
    end

    local function inspectItemsPage()
        local rows = {}
        for _, item in ipairs(Character.eachItem(u.char)) do
            rows[#rows + 1] = { label = item.name or item.id, kind = "info", item = item }
        end
        if #rows == 0 then rows[1] = { label = "(no items)", kind = "info" } end
        return listPage("Inspect items", rows)
    end

    local function giveItemPage()
        local rows = {}
        for _, id in ipairs(sortedIds(Item.defs)) do
            local def = Item.defs[id]
            rows[#rows + 1] = { label = def.name or id, kind = "action",
                -- The hover tooltip's subject, built on demand: this page lists the whole catalog and
                -- only the row you stop on is ever inspected (DebugMenu:hoveredItem caches it).
                itemGet = function() return Item.instantiate(id) end,
                act = function()
                    -- Re-run Trait.attach so an item handed over mid-battle actually contributes its
                    -- traits (they are otherwise snapshotted only when a unit joins the fight).
                    if Combat.grantItem(combat, u, id) then Trait.attach(u) end
                end }
        end
        return listPage("Give item", rows)
    end

    local function removeItemPage()
        local rows = {}
        for _, item in ipairs(Character.eachItem(u.char)) do
            rows[#rows + 1] = { label = item.name or item.id, kind = "action", item = item,
                act = function() Character.removeItem(u.char, item) end }
        end
        if #rows == 0 then rows[1] = { label = "(no items)", kind = "info" } end
        return listPage("Remove item", rows)
    end

    local function itemsPage()
        return listPage("Items", {
            { label = "Inspect", kind = "submenu", build = inspectItemsPage },
            { label = "Give item", kind = "submenu", build = giveItemPage },
            { label = "Remove item", kind = "submenu", build = removeItemPage },
        })
    end

    local function initiativePage()
        return listPage("Initiative", {
            { label = "Act next", kind = "action", act = function() u.initiative = 0 end },
            { label = "Set value", kind = "submenu", build = function()
                return stepperPage("Set initiative", {
                    value = math.floor(u.initiative or 0), min = 0, max = 999, step = 1, presets = { 0, 10, 25, 50 },
                    apply = function(v) u.initiative = v end,
                })
            end },
        })
    end

    local function controlPage()
        return listPage("Control", {
            { label = "Player", kind = "action", act = function() u.control = "player" end },
            { label = "AI", kind = "action", act = function() u.control = "ai" end },
            { label = "None", kind = "action", act = function() u.control = "none" end },
        })
    end

    local function goldPage()
        -- One "Add gold" button, but it credits the pot the unit ACTUALLY spends (Combat.purseAvailable
        -- is side-aware): a party caster draws the shared battle purse (combat.purse), an enemy its own
        -- coffer. Topping up a party unit's coffer would drop gold into a pot the party never reads, so
        -- route party-side through purse.add and fall back to the coffer for enemies. states/battle.lua
        -- now injects a purse into EVERY fight (campaign bank, draft wallet, or a transient pot for a
        -- duel/mock battle), so the party path funds a real spendable pot in every mode; the coffer
        -- fallback is retained only for the enemy side.
        return stepperPage("Add gold", { value = 0, min = 0, max = 9999, step = 5, presets = { 10, 25, 50, 100 },
            presetAdds = true,
            apply = function(v)
                if u.side == "party" and combat.purse and combat.purse.add then
                    combat.purse.add(v)
                else
                    u.coffer = (u.coffer or 0) + v
                end
            end })
    end

    local function unitRoot()
        return listPage(string.format("%s (%s)", (u.char and u.char.name) or "Unit", u.side or "?"), {
            { label = "Damage", kind = "submenu", build = damagePage },
            { label = "Kill", kind = "submenu", build = killPage },
            { label = "Heal / HP", kind = "submenu", build = healPage },
            { label = "Apply status", kind = "submenu", build = applyStatusPage },
            { label = "Remove status", kind = "submenu", build = removeStatusPage },
            { label = "Items", kind = "submenu", build = itemsPage },
            { label = "Set initiative", kind = "submenu", build = initiativePage },
            { label = "Control", kind = "submenu", build = controlPage },
            { label = "Grant extra action", kind = "action", act = function() Combat.grantExtraAction(u, 1) end },
            { label = u.debugInvuln and "Invulnerable: ON" or "Invulnerable: OFF", kind = "action",
                act = function() u.debugInvuln = not u.debugInvuln end },
            { label = "Add gold", kind = "submenu", build = goldPage },
            { label = "Clone", kind = "action", act = function()
                local tx, ty = Combat.openTileNear(combat, u.x, u.y, u.w or 1, u.h or 1)
                if tx then Combat.addUnit(combat, Character.instantiate(u.char.id), u.side, tx, ty) end
            end },
            { label = "Remove unit", kind = "action", act = function() Combat.dismiss(combat, u) end },
            { label = "Move to tile...", kind = "action", act = function()
                if menu.onPickTile then
                    menu.onPickTile(function(tx, ty) Combat.teleportUnit(combat, u, tx, ty) end)
                end
            end },
        })
    end

    -- ---- terrain builders -----------------------------------------------------------------------
    local function summonPage()
        local rows = {}
        for _, id in ipairs(sortedIds(Character.defs)) do
            local def = Character.defs[id]
            rows[#rows + 1] = { label = def.name or id, kind = "submenu", build = function()
                return listPage("Side", {
                    { label = "Party", kind = "action", act = function()
                        Combat.addUnit(combat, Character.instantiate(id), "party", tile.x, tile.y)
                    end },
                    { label = "Enemy", kind = "action", act = function()
                        Combat.addUnit(combat, Character.instantiate(id), "enemy", tile.x, tile.y)
                    end },
                })
            end }
        end
        return listPage("Summon character", rows)
    end

    local function placeListPage(title, defs, place)
        local rows = {}
        for _, id in ipairs(sortedIds(defs)) do
            local def = defs[id]
            rows[#rows + 1] = { label = def.name or id, kind = "action", act = function() place(id) end }
        end
        return listPage(title, rows)
    end

    local function terrainPage()
        local rows = {}
        for _, t in ipairs(sortedIds(Arena.TILE_PROPS)) do
            rows[#rows + 1] = { label = t, kind = "action", act = function()
                local p = Arena.TILE_PROPS[t]
                local tiles = combat.arena and combat.arena.tiles
                local c = tiles and tiles[tile.y] and tiles[tile.y][tile.x]
                if c and p then
                    c.type = t; c.moveCost = p.moveCost; c.walkable = p.walkable; c.sightCost = p.sightCost
                    c.tags = p.tags; c.bonus = p.bonus
                end
            end }
        end
        return listPage("Change terrain", rows)
    end

    local function terrainRoot()
        return listPage(string.format("Tile %d,%d", tile.x, tile.y), {
            { label = "Summon character", kind = "submenu", build = summonPage },
            { label = "Place hazard", kind = "submenu", build = function()
                return placeListPage("Place hazard", Hazard.defs,
                    function(id) Hazard.place(combat, tile.x, tile.y, id, { side = "enemy" }) end)
            end },
            { label = "Place trap", kind = "submenu", build = function()
                return placeListPage("Place trap", Trap.defs,
                    function(id) Trap.place(combat, tile.x, tile.y, id, "enemy") end)
            end },
            { label = "Place prop", kind = "submenu", build = function()
                return placeListPage("Place prop", Prop.defs,
                    function(id) Prop.place(combat, tile.x, tile.y, id) end)
            end },
            { label = "Change terrain", kind = "submenu", build = terrainPage },
        })
    end

    self.stack = { u and unitRoot() or terrainRoot() }
    self:layout()
    return self
end

function DebugMenu:top() return self.stack[#self.stack] end

-- Recompute the box rect (and, for a stepper page, its control rects) from the current top page.
-- Cheap; called on every push/pop. Position drops from the cursor, clamped fully on-screen.
function DebugMenu:layout()
    local page = self:top()
    local bodyH
    if page.kind == "stepper" then
        bodyH = 3 * ROW_H
    else
        bodyH = math.min(#page.rows, MAX_ROWS) * ROW_H
    end
    self.w = MENU_W
    self.h = PAD + HEADER_H + bodyH + PAD
    self.x = math.max(8, math.min(Scale.WIDTH - self.w - 8, math.floor(self.ax)))
    self.y = math.max(8, math.min(Scale.HEIGHT - self.h - 8, math.floor(self.ay)))

    local bodyY = self.y + PAD + HEADER_H
    if page.kind == "stepper" then
        self.stepLeft = { x = self.x + PAD, y = bodyY, w = ROW_H, h = ROW_H }
        self.stepRight = { x = self.x + self.w - PAD - ROW_H, y = bodyY, w = ROW_H, h = ROW_H }
        local n = #page.presets
        self.presetRects = {}
        if n > 0 then
            local pw = (self.w - 2 * PAD - (n - 1) * 4) / n
            for i = 1, n do
                self.presetRects[i] = { x = self.x + PAD + (i - 1) * (pw + 4), y = bodyY + ROW_H, w = pw, h = ROW_H }
            end
        end
        self.applyRect = { x = self.x + PAD, y = bodyY + 2 * ROW_H, w = self.w - 2 * PAD, h = ROW_H }
    else
        self.stepLeft, self.stepRight, self.presetRects, self.applyRect = nil, nil, nil, nil
    end
end

function DebugMenu:push(page) self.stack[#self.stack + 1] = page; self:layout() end

function DebugMenu:back()
    table.remove(self.stack)
    if #self.stack == 0 then self:close() else self:layout() end
end

function DebugMenu:close()
    if self.closed then return end
    self.closed = true
    if self.onClose then self.onClose() end
end

function DebugMenu:update(dt) end

-- The visible window of a list page and the row index under a pixel (or nil).
function DebugMenu:visibleCount(page) return math.min(#viewRows(page), MAX_ROWS) end

function DebugMenu:rowAt(x, y)
    local page = self:top()
    if page.kind ~= "list" then return nil end
    if x < self.x or x > self.x + self.w then return nil end
    local bodyY = self.y + PAD + HEADER_H
    local rel = y - bodyY
    if rel < 0 then return nil end
    local i = math.floor(rel / ROW_H) + 1
    if i < 1 or i > self:visibleCount(page) then return nil end
    local idx = page.scroll + i
    if idx > #viewRows(page) then return nil end
    return idx
end

-- Rebuild a list page's filtered view from its search string (case-insensitive substring on the
-- label), then clamp the cursor/scroll back into the shortened range.
function DebugMenu:applyFilter(page)
    local q = page.search or ""
    if q == "" then
        page.filtered = nil
    else
        local lq = q:lower()
        local out = {}
        for _, row in ipairs(page.rows) do
            if tostring(row.label):lower():find(lq, 1, true) then out[#out + 1] = row end
        end
        page.filtered = out
    end
    page.cursor = math.max(1, math.min(page.cursor, math.max(1, #viewRows(page))))
    page.scroll = 0
    self:ensureVisible(page)
end

-- Keep the cursor row inside the scrolled window after a keyboard move.
function DebugMenu:ensureVisible(page)
    local vis = self:visibleCount(page)
    if page.cursor < page.scroll + 1 then page.scroll = page.cursor - 1 end
    if page.cursor > page.scroll + vis then page.scroll = page.cursor - vis end
    page.scroll = math.max(0, math.min(page.scroll, #viewRows(page) - vis))
end

-- The item the cursored row stands for, or nil on a row that names none. The Items pages tag their
-- rows with either a live `item` (Inspect / Remove, which point at the unit's own instances) or an
-- `itemGet` builder (Give item, which would otherwise instantiate the entire catalog to list it);
-- the builder's result is cached back onto the row, so hovering costs one instantiate per entry.
function DebugMenu:hoveredItem()
    local page = self:top()
    if page.kind ~= "list" then return nil end
    local row = viewRows(page)[page.cursor]
    if not row then return nil end
    if not row.item and row.itemGet then row.item = row.itemGet() end
    return row.item
end

-- Fire the row `idx` on the current list page: descend a submenu, run an action (then close), or
-- ignore an info row. Any mutation is followed by refresh() so the board/turn strip re-derive.
function DebugMenu:activate(idx)
    local page = self:top()
    local rows = viewRows(page)
    local row = rows and rows[idx]
    if not row then return end
    if row.kind == "submenu" then
        self:push(row.build())
    elseif row.kind == "action" then
        if row.act then row.act() end
        self.refresh()
        self:close()
    end
end

function DebugMenu:stepAdjust(delta)
    local page = self:top()
    if page.kind ~= "stepper" then return end
    page.value = math.max(page.min, math.min(page.max, page.value + delta * page.step))
end

function DebugMenu:stepApply()
    local page = self:top()
    if page.kind ~= "stepper" then return end
    if page.apply then page.apply(page.value) end
    self.refresh()
    self:close()
end

-- A preset button was pressed. On a presetAdds page it ADDS its amount to the running value (clamped),
-- so tapping presets on Add gold dials a total that Apply then grants; otherwise it just loads the
-- value for review/Apply.
function DebugMenu:stepPreset(i)
    local page = self:top()
    if page.kind ~= "stepper" then return end
    local v = page.presets[i]
    if v == nil then return end
    if page.presetAdds then
        page.value = math.max(page.min, math.min(page.max, page.value + v))
    else
        page.value = v
    end
end

-- ---- drawing ------------------------------------------------------------------------------------
function DebugMenu:draw()
    local page = self:top()
    Theme.plate(self.x, self.y, self.w, self.h, Theme.R)
    love.graphics.setFont(self.font)
    local fh = self.font:getHeight()

    -- Header: the target this page acts on (or the page title as it descends). A list page with an
    -- active type-to-search filter shows the query after the title (e.g. `Give item  /swo`).
    local title = page.title
    if page.kind == "list" and page.search and page.search ~= "" then
        title = title .. "  /" .. page.search
    end
    Theme.set(Theme.accentAmber)
    love.graphics.print(Theme.ellipsize(title, self.font, self.w - 2 * PAD),
        self.x + PAD, self.y + PAD + (HEADER_H - fh) / 2)

    if page.kind == "stepper" then
        self:drawStepper(page, fh)
    else
        self:drawList(page, fh)
        self:drawItemTooltip(page)
    end
    love.graphics.setColor(1, 1, 1)
end

-- Float the shared item tooltip (ui/item_tooltip.lua) beside the box while an item row is cursored,
-- so Give item / Inspect / Remove read as more than a list of names. It follows the CURSOR, not the
-- pointer -- mousemoved parks the cursor under the mouse, so keyboard and pad get the same card.
-- The box is pinned to the menu's right edge (left when there is no room, forced by capping the
-- tooltip's own maxRight at our left edge), never over the rows it describes. battle.lua draws the
-- debug menu last, so this lands above the board and the combat panel.
function DebugMenu:drawItemTooltip(page)
    local item = self:hoveredItem()
    if not item then return end
    local rowY = self.y + PAD + HEADER_H + (page.cursor - page.scroll - 1) * ROW_H
    local right = self.x + self.w
    if right + ItemTooltip.WIDTH + 18 <= Scale.WIDTH then
        ItemTooltip.draw(item, right, rowY - 16, Scale.WIDTH, self.unit)
    else
        ItemTooltip.draw(item, self.x, rowY - 16, self.x, self.unit)
    end
end

function DebugMenu:drawList(page, fh)
    local rows = viewRows(page)
    local vis = self:visibleCount(page)
    local bodyY = self.y + PAD + HEADER_H
    if #rows == 0 then
        Theme.set(Theme.muted)
        love.graphics.print("(no match)", self.x + PAD, bodyY + (ROW_H - fh) / 2)
        return
    end
    for i = 1, vis do
        local idx = page.scroll + i
        local row = rows[idx]
        if row then
            local ry = bodyY + (i - 1) * ROW_H
            -- An info row is inert and normally draws no cursor -- unless it carries an item, where
            -- the ring is what tells you which name the floating tooltip belongs to (Inspect items).
            if idx == page.cursor and (row.kind ~= "info" or row.item or row.itemGet) then
                Theme.set(Theme.slot)
                love.graphics.rectangle("fill", self.x + 2, ry, self.w - 4, ROW_H)
                Theme.set(Theme.cursor)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", self.x + 2, ry, self.w - 4, ROW_H)
                love.graphics.setLineWidth(1)
            end
            Theme.set(row.kind == "info" and Theme.muted or Theme.ink)
            love.graphics.print(Theme.ellipsize(row.label, self.font, self.w - 2 * PAD - 12),
                self.x + PAD, ry + (ROW_H - fh) / 2)
            if row.kind == "submenu" then
                Theme.set(Theme.muted)
                love.graphics.print(">", self.x + self.w - PAD - 8, ry + (ROW_H - fh) / 2)
            end
        end
    end
    -- Scroll hints when the list overflows its window.
    if #rows > vis then
        Theme.set(Theme.muted)
        if page.scroll > 0 then love.graphics.print("^", self.x + self.w - PAD - 8, self.y + PAD) end
        if page.scroll + vis < #rows then
            love.graphics.print("v", self.x + self.w - PAD - 8, self.y + self.h - PAD - fh)
        end
    end
end

function DebugMenu:drawStepper(page, fh)
    local function button(r, label, hot)
        Theme.set(hot and Theme.accentAmber or Theme.frame)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 2, 2)
        Theme.set(hot and Theme.slot or Theme.ink)
        love.graphics.printf(label, r.x, r.y + (r.h - fh) / 2, r.w, "center")
    end
    button(self.stepLeft, "-", self.hot == "left")
    button(self.stepRight, "+", self.hot == "right")
    -- The value, centred between the two arrows.
    Theme.set(Theme.ink)
    love.graphics.printf(tostring(page.value), self.stepLeft.x, self.stepLeft.y + (ROW_H - fh) / 2,
        self.stepRight.x - self.stepLeft.x, "center")
    for i, r in ipairs(self.presetRects or {}) do
        button(r, tostring(page.presets[i]), self.hot == "preset" .. i)
    end
    button(self.applyRect, "Apply", self.hot == "apply")
end

-- ---- input --------------------------------------------------------------------------------------
function DebugMenu:mousemoved(x, y)
    local page = self:top()
    if page.kind == "list" then
        local idx = self:rowAt(x, y)
        if idx then page.cursor = idx end
    else
        self.hot = nil
        if pointIn(self.stepLeft, x, y) then self.hot = "left"
        elseif pointIn(self.stepRight, x, y) then self.hot = "right"
        elseif pointIn(self.applyRect, x, y) then self.hot = "apply"
        else
            for i, r in ipairs(self.presetRects or {}) do
                if pointIn(r, x, y) then self.hot = "preset" .. i break end
            end
        end
    end
end

function DebugMenu:cursorKind(x, y)
    local page = self:top()
    if page.kind == "list" then
        local idx = self:rowAt(x, y)
        local row = idx and viewRows(page)[idx] -- the filtered view, which is what rowAt indexes
        if row and row.kind ~= "info" then return "hand" end
    else
        if pointIn(self.stepLeft, x, y) or pointIn(self.stepRight, x, y) or pointIn(self.applyRect, x, y) then
            return "hand"
        end
        for _, r in ipairs(self.presetRects or {}) do
            if pointIn(r, x, y) then return "hand" end
        end
    end
    return "arrow"
end

function DebugMenu:mousepressed(x, y, button)
    if button == 2 then self:back() return end
    if button ~= 1 then return end
    -- A click off the box backs out one level (out of a submenu, or shut from the root).
    if x < self.x or x > self.x + self.w or y < self.y or y > self.y + self.h then self:back() return end
    local page = self:top()
    if page.kind == "list" then
        local idx = self:rowAt(x, y)
        if idx then page.cursor = idx; self:activate(idx) end
    else
        if pointIn(self.stepLeft, x, y) then self:stepAdjust(-1)
        elseif pointIn(self.stepRight, x, y) then self:stepAdjust(1)
        elseif pointIn(self.applyRect, x, y) then self:stepApply()
        else
            for i, r in ipairs(self.presetRects or {}) do
                if pointIn(r, x, y) then self:stepPreset(i) break end
            end
        end
    end
end

function DebugMenu:mousereleased(x, y, button) end

function DebugMenu:wheelmoved(dx, dy)
    if dy == 0 then return end
    local page = self:top()
    if page.kind == "list" then
        local vis = self:visibleCount(page)
        local n = #viewRows(page)
        if n > vis then
            page.scroll = math.max(0, math.min(page.scroll - dy, n - vis))
        end
    else
        self:stepAdjust(dy > 0 and 1 or -1)
    end
end

-- A typed character extends the current list page's search filter. (main.lua forwards love.textinput
-- through battle.textinput to here.) Space is handled in keypressed as "activate", so it never
-- reaches here as a search char -- filters are single words, which is plenty for these catalogs.
function DebugMenu:textinput(t)
    local page = self:top()
    if page.kind ~= "list" then return end
    if t == " " or #t ~= 1 or t:byte() < 33 then return end -- printable, non-space ASCII only
    page.search = (page.search or "") .. t
    self:applyFilter(page)
end

function DebugMenu:keypressed(key)
    local page = self:top()
    -- While a list filter is active, Backspace edits it and Esc clears it, rather than popping the
    -- page -- so type-to-search never traps you (Esc twice still backs out).
    if page.kind == "list" and page.search and page.search ~= "" then
        if key == "backspace" then
            page.search = page.search:sub(1, -2); self:applyFilter(page); return
        elseif key == "escape" then
            page.search = ""; self:applyFilter(page); return
        end
    end
    if key == "escape" or key == "backspace" then self:back() return end
    if page.kind == "list" then
        local n = #viewRows(page)
        if key == "up" then
            page.cursor = page.cursor > 1 and page.cursor - 1 or n
            self:ensureVisible(page)
        elseif key == "down" then
            page.cursor = page.cursor < n and page.cursor + 1 or 1
            self:ensureVisible(page)
        elseif key == "return" or key == "kpenter" or key == "space" or key == "right" then
            self:activate(page.cursor)
        end
    else
        if key == "left" or key == "-" or key == "kp-" then self:stepAdjust(-1)
        elseif key == "right" or key == "=" or key == "kp+" then self:stepAdjust(1)
        elseif key == "return" or key == "kpenter" or key == "space" then self:stepApply()
        end
    end
end

function DebugMenu:gamepadpressed(joystick, button)
    if button == "b" then self:back() return end
    local page = self:top()
    if page.kind == "list" then
        local n = #viewRows(page)
        if button == "dpup" then
            page.cursor = page.cursor > 1 and page.cursor - 1 or n
            self:ensureVisible(page)
        elseif button == "dpdown" then
            page.cursor = page.cursor < n and page.cursor + 1 or 1
            self:ensureVisible(page)
        elseif button == "a" or button == "dpright" then
            self:activate(page.cursor)
        end
    else
        if button == "dpleft" or button == "leftshoulder" then self:stepAdjust(-1)
        elseif button == "dpright" or button == "rightshoulder" then self:stepAdjust(1)
        elseif button == "a" then self:stepApply()
        end
    end
end

return DebugMenu
