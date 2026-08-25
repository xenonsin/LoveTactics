-- The debug context menu: a cursor-anchored dropdown that pops up on RIGHT-CLICK, in development
-- builds only (every host gates its creation on Debug.enabled, exactly as states/battle.lua gates the
-- Win/Lose buttons). It comes in two flavours, told apart by what was under the cursor.
--
-- DebugMenu.new -- the BOARD menu, during a battle. Reads the tile under the pointer:
--   * a living unit there -> the unit page (damage, kill, heal, statuses, items, initiative, control,
--     animations, extra action, invulnerable, gold, clone, remove, move-to-tile)
--   * empty ground        -> the terrain page (summon, place hazard/trap/prop, change terrain)
--
-- DebugMenu.forItem -- the ITEM menu, wherever an item is on show: the Loadout grid and stash
-- (ui/panels/party.lua), a vendor shelf (ui/panels/shop.lua, ui/panels/merchant.lua) and the acting
-- unit's cards mid-fight (states/battle.lua). It answers the question you ask while reading an item
-- and cannot answer from the tooltip: where does this thing LIVE, and why is it worth what it says?
--   * Open <file>.lua    -- the blueprint in an editor (models/debug.lua)
--   * Reload blueprint   -- re-read it off disk and re-stamp this copy, so an edit lands without a restart
--   * Copy id            -- the id to the clipboard, for the grep the next question needs
--   * Grade / price      -- what models/grade.lua makes of it, row by row, against the authored price
-- Its first three rows KEEP the menu open and report what happened on the page's notice line: they are
-- things you do to a file, not to the board, and closing on each one would make a reload-and-look loop
-- three right-clicks long.
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
-- The Animations page is not an exception to that: what it drives is the VIEW-side animation
-- controller (ui/combat_fx.lua, handed down as opts.fx), a different thing that happens to share the
-- name, and it moves no piece of the model at all.
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
local Debug = require("models.debug")
local Grade = require("models.grade")
local Growth = require("models.growth")
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
local MAX_ROWS = 12 -- visible list rows before the window scrolls (a page may raise its own; see listPage)
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
--
-- Two options for a page that is a READOUT rather than a set of commands (the item menu's Grade page,
-- and its root, which acts on files instead of the board):
--   opts.w       a wider box, for rows that carry a label AND a figure
--   opts.maxRows a taller window before it scrolls. A CATALOG scrolls -- there is no height that fits
--                every status in the game, and type-to-search is how you get down it. A report is a
--                fixed handful of lines that are read TOGETHER, and scrolling one is just hiding half
--                the answer, so it gets the room instead.
--   row.keep     an action that leaves the menu open, and whose act() may return a line of text --
--                shown on the page's notice line, since a row that does not close has no other way to
--                say it did anything. See DebugMenu:activate.
local function listPage(title, rows, opts)
    opts = opts or {}
    return { kind = "list", title = title, rows = rows, cursor = 1, scroll = 0, search = "",
        w = opts.w, maxRows = opts.maxRows }
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

-- Everything both flavours are made of, before either one has a page: where the box drops from, the
-- font it reads in, and the three callbacks the host hands down. Split out so DebugMenu.forItem is a
-- different ROOT PAGE and nothing else -- the stack, the layout, the drawing and all three input
-- devices below are written against `page`, and never ask which menu they belong to.
local function base(opts)
    local self = setmetatable({}, DebugMenu)
    self.combat = opts.combat
    self.unit = opts.unit
    self.tile = opts.tile or { x = 1, y = 1 }
    self.onClose = opts.onClose or function() end
    self.onPickTile = opts.onPickTile
    self.refresh = opts.refresh or function() end
    self.fx = opts.fx -- the board's animation controller, for the Animations page (optional)
    self.font = Theme.body(FONT_SIZE)
    self.ax = opts.x or Scale.WIDTH / 2
    self.ay = opts.y or Scale.HEIGHT / 2
    self.closed = false
    return self
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
    local self = base(opts)

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

    -- Walk one item up or down the forge ladder in place. The one lever the panel was missing for
    -- TUNING rather than for reaching content: a magnitude is a per-level curve (models/curve.lua) and
    -- the only way to see what a rung actually buys was to leave the battle, pay a bench and come
    -- back. Re-instantiates from the blueprint at the new level -- the same thing Forge.upgrade does,
    -- so nothing compounds -- then re-folds the bearer's passives, since armour rungs move unit.bonus.
    local function forgeItemsPage()
        local rows = {}
        for cell, item in pairs(u.char.inventory) do
            if Item.isUpgradable(item) then
                rows[#rows + 1] = { label = string.format("%s  (+%d)", item.name or item.id, item.level or 0),
                    kind = "action", item = item,
                    act = function()
                        local next = math.min(Item.MAX_LEVEL, (item.level or 0) + 1)
                        u.char.inventory[cell] = Item.instantiate(item.id, item.quantity, next)
                        Combat.refreshPassives(u)
                        Trait.attach(u)
                    end }
            end
        end
        table.sort(rows, function(a, b) return a.label < b.label end)
        if #rows == 0 then rows[1] = { label = "(nothing forgeable)", kind = "info" } end
        return listPage("Forge +1", rows)
    end

    local function itemsPage()
        return listPage("Items", {
            { label = "Inspect", kind = "submenu", build = inspectItemsPage },
            { label = "Forge +1", kind = "submenu", build = forgeItemsPage },
            { label = "Give item", kind = "submenu", build = giveItemPage },
            { label = "Remove item", kind = "submenu", build = removeItemPage },
        })
    end

    -- "Level up TO", not "set level": Growth.resolve only ever climbs (models/growth.lua) because
    -- gains are baked into char.stats and history is never re-apportioned. A row promising to set a
    -- level would silently do nothing on the way down, so it says what it does.
    local function levelPage()
        return stepperPage("Level up to", {
            value = math.floor(u.char.level or 1), min = 1, max = Growth.LEVEL_CAP, step = 1,
            presets = { 5, 10, 20, Growth.LEVEL_CAP },
            apply = function(v)
                Growth.resolve(u.char, v)
                Combat.refreshPassives(u)
            end,
        })
    end

    -- Every damaging thing this unit holds against every foe on the board, in one grid.
    --
    -- The per-hit receipt already exists (Combat.damageBreakdown, hovered in the combat log) and
    -- answers "why was that number what it was". This answers the question a TUNER has instead --
    -- "which of my tools works on which of them" -- which no amount of hovering one line at a time
    -- gives you. A floored cell is marked, because that is the failure this whole system exists to
    -- catch. Read-only: it computes through Combat.computeDamage and mutates nothing.
    local function damageTablePage()
        local rows = {}
        local foes = {}
        for _, other in ipairs(combat.units) do
            if other.alive and other.side ~= u.side then foes[#foes + 1] = other end
        end

        -- One row per (weapon, foe) rather than a wide grid line: a menu row is clipped to the panel
        -- width, and three foes across turned the second one into "Kni...". Vertical cannot truncate,
        -- and the page already scrolls.
        for _, item in ipairs(Character.eachItem(u.char)) do
            local ab = item.activeAbility
            if ab and ab.damage then
                rows[#rows + 1] = { kind = "info", label = item.name or item.id }
                if #foes == 0 then
                    rows[#rows + 1] = { kind = "info", label = "   (no foes on the board)" }
                end
                for _, foe in ipairs(foes) do
                    local d = Combat.computeDamage(combat, u, foe, item)
                    -- Floored = mitigation ate the blow and only the minimum share got through.
                    local floored = d <= math.max(1, math.floor(
                        Combat.abilityMagnitude(ab) * (Combat.MIN_DAMAGE_SHARE or 0)))
                    local hp = foe.char.stats.health
                    local cur = (type(hp) == "table") and hp.current or hp or 0
                    rows[#rows + 1] = { kind = "info", label = string.format("   %-20s %3d%s  (%d hits)",
                        (foe.char.name or foe.char.id):sub(1, 20), d, floored and " !" or "  ",
                        d > 0 and math.ceil(cur / d) or 0) }
                end
            end
        end
        if #rows == 0 then rows[1] = { label = "(nothing that deals damage)", kind = "info" } end
        rows[#rows + 1] = { label = "! = floored by armour", kind = "info" }
        return listPage("Damage table", rows)
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

    -- The six-clip animation set (ui/combat_fx.lua), fired on demand. These curves are the board's
    -- whole character animation -- there is no rig -- and the only way to judge one is to watch it, so
    -- this page exists to stop that meaning "start a battle and hope somebody takes a heavy hit".
    --
    -- The speed rows come FIRST and keep the menu open, because that is the order the page is used in:
    -- an attack is sixteen frames at full speed and the wind-up inside it is three, so you slow it down
    -- and THEN pick a clip. Each clip row closes the menu, since the next thing you want is the board.
    -- Nothing here touches the model: a demonstrated collapse leaves a live unit standing.
    local function animationsPage()
        local fx = menu.fx
        if not fx then
            return listPage("Animations", { { label = "no animation controller", kind = "info" } })
        end
        -- Everything with a direction is aimed at the nearest OTHER body, so a lunge, a recoil and a
        -- collapse all read against something that is actually on the board. With the field to itself
        -- the controller falls back to a phantom tile to the east (CombatFx:demo).
        local target, best
        for _, o in ipairs(combat.units or {}) do
            if o ~= u and o.alive then
                local d = math.abs(o.x - u.x) + math.abs(o.y - u.y)
                if not best or d < best then best, target = d, o end
            end
        end
        local rows = {}
        for _, s in ipairs({ 1, 0.5, 0.25, 0.1 }) do
            rows[#rows + 1] = { label = string.format("Speed %gx", s), kind = "action", keep = true,
                act = function() fx:setTimeScale(s) return string.format("playing at %gx", s) end }
        end
        rows[#rows + 1] = { label = "-- clips --", kind = "info" }
        rows[#rows + 1] = { label = "Play all (in order)", kind = "action",
            act = function() fx:demo(u, target) end }
        for _, c in ipairs({
            { "Walk (a step in)", "walk" },
            { "Attack (wind-up, strike)", "attack" },
            { "Hit -- a scratch", "hit" },
            { "Hit -- a heavy blow", "heavy" },
            { "Cast (aimed)", "cast" },
            { "Cast (on itself)", "selfcast" },
            { "Collapse", "death" },
        }) do
            rows[#rows + 1] = { label = c[1], kind = "action",
                act = function() fx:demo(u, target, c[2]) end }
        end
        rows[#rows + 1] = { label = "-- idle runs on its own --", kind = "info" }
        return listPage("Animations", rows, { maxRows = 15 })
    end

    local function unitRoot()
        return listPage(string.format("%s (%s)", (u.char and u.char.name) or "Unit", u.side or "?"), {
            { label = "Damage", kind = "submenu", build = damagePage },
            { label = "Kill", kind = "submenu", build = killPage },
            { label = "Heal / HP", kind = "submenu", build = healPage },
            { label = "Apply status", kind = "submenu", build = applyStatusPage },
            { label = "Remove status", kind = "submenu", build = removeStatusPage },
            { label = "Items", kind = "submenu", build = itemsPage },
            { label = "Damage table", kind = "submenu", build = damageTablePage },
            { label = "Animations", kind = "submenu", build = animationsPage },
            { label = "Level up to...", kind = "submenu", build = levelPage },
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

-- ---------------------------------------------------------------------------
-- The item menu
-- ---------------------------------------------------------------------------

local ITEM_MENU_W = 236  -- wider than the board menu: its rows carry a file name, not a verb
local GRADE_PAGE_W = 300    -- wider again: every row is a label AND a figure, right-aligned
local GRADE_PAGE_ROWS = 22  -- and taller: the readout is one answer, and half of it is not an answer

-- One "label ....... figure" row for the grade readout. Inert by construction: the page is a report,
-- and nothing on it is a control. `figure` is drawn right-aligned by DebugMenu:drawList off `row.rhs`.
local function readout(label, figure)
    return { label = label, kind = "info", rhs = figure and tostring(figure) or nil }
end

-- Round to one decimal, as a string, so a column of grades lines up instead of running to Lua's
-- fourteen significant figures.
local function fig(n)
    if type(n) ~= "number" then return "-" end
    return string.format("%.1f", n)
end

-- What models/grade.lua makes of this item, row by row: the total, the active/passive split that
-- produced it, every contributing line of the breakdown, and finally what the item is AUTHORED at.
--
-- The last block is the point of the page. Price is derived -- what a thing is worth sets the slot it
-- unlocks from, and the slot sets the price (docs/shelf.md) -- so the two figures that matter are the
-- price the blueprint carries and the price its own authored slot implies. When they disagree, the
-- shelf pass has not been run since somebody last touched this file, and the page says so rather than
-- leaving it to `. grade-report` to find.
local function gradePage(item)
    local id = item.id
    local def = Item.defs[id]
    local value, breakdown = Grade.of(id)
    if not value then
        return listPage("Grade", { readout("(no grade: unknown item)") }, { w = GRADE_PAGE_W, maxRows = GRADE_PAGE_ROWS })
    end

    local rows = { readout("GRADE", fig(value)) }
    if breakdown.blind then
        -- BLIND, not weak: the dry run saw nothing because the item needs board state a boardless
        -- replay cannot have (a planted charge, a weapon beside it, a purse). Grade.of is explicit
        -- that this is a fact about the instrument, so the page must not present it as a judgement.
        rows[#rows + 1] = readout("  blind -- needs board state")
    elseif breakdown.estimated then
        rows[#rows + 1] = readout("  estimated (un-weighted trait)")
    end
    rows[#rows + 1] = readout("  active", fig(breakdown.active))
    rows[#rows + 1] = readout("  passive", fig(breakdown.passive))

    rows[#rows + 1] = readout("-- breakdown --")
    for _, r in ipairs(breakdown.rows) do
        rows[#rows + 1] = readout("  " .. tostring(r[1]), fig(r[2]))
    end

    rows[#rows + 1] = readout("-- authored --")
    rows[#rows + 1] = readout("  class", def.class or "(none)")
    local slot = def.unlockQuests or 0
    rows[#rows + 1] = readout("  slot (unlockQuests)", slot)
    rows[#rows + 1] = readout("  price", def.price and (def.price .. "g") or "(unsold)")
    if def.price then
        local implied = Grade.priceFor(slot, def.type)
        rows[#rows + 1] = readout("  price for that slot", implied .. "g")
        if implied ~= def.price then
            rows[#rows + 1] = readout("  ! stale: run grade-report apply")
        end
    end

    return listPage(("Grade: %s"):format(def.name or id), rows, { w = GRADE_PAGE_W, maxRows = GRADE_PAGE_ROWS })
end

-- opts:
--   x, y      the cursor position the menu drops from
--   item      the right-clicked item INSTANCE (the live table, so a reload re-stamps the copy on show)
--   unit      the combat unit holding it, when there is one -- priced tooltips only
--   onClose   fn() -- clear the host's menu field
--   refresh   fn() -- called after a reload so the host re-derives whatever it drew off the item
--
-- Returns nil in a release build and for an item whose blueprint the catalog does not know (a
-- hand-built instance), so a host can write `menu = DebugMenu.forItem{...}` and let the nil say no.
function DebugMenu.forItem(opts)
    opts = opts or {}
    local item = opts.item
    if not Debug.enabled or not item or not item.id or not Item.defs[item.id] then return nil end

    local self = base(opts)
    self.item = item

    local id = item.id
    local rel = Item.paths[id]
    local file = rel and (rel:match("([^/]+)$") or rel) or nil

    local rows = {}

    -- Row 1, and the reason the menu exists: the blueprint in an editor. The path is printed as well
    -- as opened -- if nothing answers (no association for .lua, no $LOVETACTICS_EDITOR), the console
    -- still says exactly where to go, which is the whole ask minus the convenience.
    if file then
        rows[#rows + 1] = { label = "Open " .. file, kind = "action", keep = true, act = function()
            print(("item: %s"):format(rel))
            return Debug.openFile(rel) and ("opened " .. file) or "no editor answered -- path in console"
        end }
    else
        rows[#rows + 1] = readout("(no source file)")
    end

    -- Row 2 closes the loop row 1 opens: change a number in the editor, reload, look again. It swaps
    -- the blueprint AND re-stamps this instance from it, because the copy in your hand was taken at
    -- instantiate time and would otherwise still be showing the old figures -- a reload you cannot see
    -- is indistinguishable from one that failed.
    if rel then
        rows[#rows + 1] = { label = "Reload blueprint", kind = "action", keep = true, act = function()
            local ok, err, stale = Item.reload(id)
            if not ok then return "reload failed: " .. tostring(err) end
            Item.restamp(item, stale)
            Grade.reset() -- the grade page memoizes; a reloaded blueprint invalidates every figure on it
            return "reloaded " .. (file or id)
        end }
    end

    rows[#rows + 1] = { label = "Copy id", kind = "action", keep = true, act = function()
        local set = love.system and love.system.setClipboardText
        if not set then return "no clipboard" end
        set(id)
        return "copied " .. id
    end }

    rows[#rows + 1] = { label = "Grade / price", kind = "submenu", build = function() return gradePage(item) end }

    self.stack = { listPage(item.name or id, rows, { w = ITEM_MENU_W }) }
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
        bodyH = math.min(#page.rows, page.maxRows or MAX_ROWS) * ROW_H
        -- A `keep` row's notice sits under the list, in the box, so what just happened is reported
        -- where the row that did it still is. It only ever costs the height once it has something to
        -- say, so a page that has not been acted on is exactly as tall as its rows.
        if page.notice then bodyH = bodyH + ROW_H end
    end
    self.w = page.w or MENU_W
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
function DebugMenu:visibleCount(page) return math.min(#viewRows(page), page.maxRows or MAX_ROWS) end

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
        local said = row.act and row.act() or nil
        self.refresh()
        -- A `keep` row acts on a FILE rather than the board: closing on each one would make an
        -- open-edit-reload-look loop three right-clicks long. It stays, and whatever act() said goes
        -- on the notice line, since a menu that does not close has no other way to report itself.
        if row.keep then
            page.notice = type(said) == "string" and said or nil
            self:layout()
        else
            self:close()
        end
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
        -- What the last `keep` row did, on its own line at the body's foot (layout has already made
        -- room for it). Drawn out here rather than inside drawList so an empty filtered view still
        -- reports it instead of swallowing it with the rows.
        if page.notice then
            local ny = self.y + PAD + HEADER_H + self:visibleCount(page) * ROW_H
            Theme.set(Theme.accentAmber)
            love.graphics.print(Theme.ellipsize(page.notice, self.font, self.w - 2 * PAD),
                self.x + PAD, ny + (ROW_H - fh) / 2)
        end
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
            -- A readout row carries a figure as well as a label (the Grade page). It is measured
            -- first and the label ellipsized against what is LEFT, so a long breakdown label loses
            -- its tail rather than running under the number it belongs to.
            local rhsW = 0
            if row.rhs then rhsW = self.font:getWidth(row.rhs) + 10 end
            Theme.set(row.kind == "info" and Theme.muted or Theme.ink)
            love.graphics.print(Theme.ellipsize(row.label, self.font, self.w - 2 * PAD - 12 - rhsW),
                self.x + PAD, ry + (ROW_H - fh) / 2)
            if row.rhs then
                Theme.set(Theme.ink)
                love.graphics.printf(row.rhs, self.x, ry + (ROW_H - fh) / 2, self.w - PAD, "right")
            end
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
