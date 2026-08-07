-- Loadout pop-up panel: arrange each roster member's 3x3 item grid, where item POSITIONING drives
-- adjacency auras/boosts/requirements (ui/adjacency_links.lua) -- that's the point of this screen, so
-- the grid gets a legend. A scrollable portrait rail runs down the LEFT, then the focused member's
-- portrait + stats, then that member's grid, then the shared stash (ui/pool_grid.lua).
-- Buying and selling live on the separate shop screen (ui/panels/shop.lua); this screen never touches
-- gold.
--
-- The panel owns EVERY item move -- the widgets never mutate ownership themselves -- so the two can't
-- disagree about who holds what. Dragging an item onto a rail portrait GIVES it to that member, so
-- cross-member transfers don't need a focus switch.
--
-- Stash -> character is one step: clicking (or confirming on) a stash item EQUIPS the whole thing to
-- the focused member's next open slot (stackables merge first). Reordering a member's grid is the
-- separate action -- pick-then-place with keyboard/gamepad, drag-and-drop with the mouse -- and a
-- mouse drag from the stash onto a specific cell/portrait is how you aim a slot, member, or quantity.
--
-- Three-input + mouse-only: click cells/rows/portraits, or drag; keyboard (arrows + Enter, Tab to
-- switch grid<->stash, Q/E character, Esc); gamepad (D-pad + A, Y grid<->stash, shoulders character,
-- B close).
--
--   local panel = Party.new({ player = player, onClose = fn })

local InventoryGrid = require("ui.inventory_grid")
local TacticsEditor = require("ui.tactics_editor")
local PoolGrid = require("ui.pool_grid")
local AdjacencyLinks = require("ui.adjacency_links")
local CloseButton = require("ui.close_button")
local QuantityPopup = require("ui.quantity_popup")
local ItemTooltip = require("ui.item_tooltip")
local StatTooltip = require("ui.stat_tooltip")
local NoteTooltip = require("ui.note_tooltip")
local ButtonPrompt = require("ui.button_prompt")
local InputMode = require("input_mode")
local Character = require("models.character")
local Player = require("models.player")
local Item = require("models.item")
local Combat = require("models.combat") -- for Combat.unpayableCosts: the equip-time affordability warning
local Growth = require("models.growth")
local Discipline = require("models.discipline")
local Debug = require("models.debug")
local Scale = require("scale")
local Theme = require("ui.theme")

local Party = {}
Party.__index = Party

local BOX_W, BOX_H = 1160, 650
local DRAG_THRESHOLD = 5
local GHOST = 48

-- Vertical roster rail down the left.
local PORTRAIT = 72
local RAIL_CELL_H = PORTRAIT + 20 -- portrait + name line
local RAIL_GAP = 8

-- Stats shown in the focus sheet, in order. `res` stats are the { max, current } pools.
local STAT_ROWS = {
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

-- Adjacency connector legend (colors from ui/adjacency_links.lua). Positioning is the mechanic this
-- screen exists for, so the legend is always shown under the grid.
local LEGEND = {
    { kind = "aura", label = "Aura (grants to neighbor)" },
    { kind = "boost", label = "Scales off neighbor" },
    { kind = "requirement", label = "Requirement met" },
}

-- Navigable regions, left to right. The focus sheet is skipped as a stop -- it has no interactive
-- cells -- so a single cursor flows Rail <-> Grid <-> Stash by pushing left/right at a column edge.
-- `filters` is appended only when the host supplies a filter strip (see opts.filters); it is not a
-- left/right stop but a Tab one, like the rule editor's own internal regions.
local REGIONS = { "rail", "grid", "pool" }

-- The tabs. `loadout` is the original screen, unchanged; `tactics` swaps the grid/stash columns for
-- the rule editor (ui/tactics_editor.lua), and the optional `stats` tab (opts.stats -- the debug
-- character editor) swaps them for the blueprint field editor. The portrait rail stays up in ALL of
-- them, so switching character works the same way whichever tab is open -- a tab is a view of one
-- member, not a different screen. Segment pattern follows ui/panels/shop.lua's Buy/Sell/Upgrade
-- selector.
--
-- `tactics` and `stats` are both COLUMN EDITORS: one widget claiming the whole area right of the
-- rail, driven through a common interface (see Party:columnEditor). Everything below branches on
-- "is there a column editor" rather than on the tab's name, so a third one costs a table entry
-- rather than another dozen `mode == "..."` tests.
local MODE_LABEL = { loadout = "Loadout", tactics = "Tactics", stats = "Stats" }
local MODE_H = 28

-- Semantic prompt-glyph tints, kept across input modes (the glyph text changes A<->Enter, the
-- meaning doesn't): confirm reads green, cancel/close red.
local PROMPT_GO = { 0.55, 0.90, 0.58 }
local PROMPT_NO = { 0.95, 0.50, 0.47 }

-- Every stat key the focus sheet prints, in row order -- what Party.equipDelta walks to decide which of
-- an item's bonuses are worth previewing. WHICH ROWS EXIST is the sheet's business and lives here; WHERE
-- a bonus to a given row lives on an item is the model's (Character.bonusField), so the two readouts
-- cannot each guess at the bonus/maxBonus split and disagree.
local SHEET_KEYS = {}
for _, row in ipairs(STAT_ROWS) do SHEET_KEYS[#SHEET_KEYS + 1] = row.key end

-- The focus sheet's stat-annotation palette. GAIN / LOSS are the signed figure beside a value while an
-- item is in hand: what equipping it would do to that number.
--
-- PENDING is the level forecast, and it is deliberately NOT written in the same grammar. A signed figure
-- parked next to a value is the universal "this is buffed right now" idiom, and when the forecast wore
-- it that is exactly how it read -- the equip delta gets away with the glyph only because it lives for
-- as long as the gesture that caused it. The forecast states a TRANSITION instead, "16 → 17", which
-- cannot describe a bonus already in effect, and it appears only while the growth clause is engaged.
local ANNOT_GAIN    = { 0.55, 0.90, 0.58 }
local ANNOT_LOSS    = { 0.95, 0.45, 0.42 }
local ANNOT_PENDING = { 0.48, 0.74, 0.51 }
local ARROW = "→"

local function pointIn(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

-- A ledger key in words. The key is a class id OR a discipline id (Discipline.growthClasses banks a
-- discipline item under the discipline), so the discipline name is tried first and title-casing is only
-- the fallback -- "plague_knight" is "Plague Knight", which title-casing alone would render
-- "Plague_knight". The same rule states/battle.lua applies to the technique floater.
local function classLabel(class)
    if not class then return "?" end
    return Discipline.displayName(class) or (class:gsub("^%l", string.upper))
end

-- What this member is growing as RIGHT NOW, ranked biggest claim first: { key, name, share }.
--
-- ONE READING, TWO PLACES ON THE SHEET, and they can no longer disagree -- which is exactly how the old
-- sheet confused people. The title line named `Growth.dominantClass`, the leader of the CAREER ledger,
-- directly above a column showing the delta since the last level-up: "Growing as Hunter" over
-- "Alchemist 33% · Hunter 25%" is two true statements about two different windows of time, and nothing
-- on the sheet said which was which. "Growing" is present-progressive, so it means the present now --
-- the title takes its name from row 1 here and the forecast beneath it prints the rest.
--
-- `share` is the delta AS A FRACTION, because the fraction is the whole of what the model reads. A
-- level arrives on prestige, not on casts, so twenty casts and two hundred casts in the same
-- proportions grow the identical character -- the magnitude buys nothing and printing it would imply a
-- rate that does not exist.
--
-- EMPTY when nothing has been cast since the last level-up. Growth.shares answers the innate class at
-- 1.0 there, which is a true statement about a hypothetical level but reads on a sheet as a claim the
-- player earned; right after a level-up the honest answer is nothing, and the title drops the clause
-- rather than inventing one.
--
-- Ranked share-desc then key-asc, the SAME order ui/panels/advancement.lua ranks the summary it prints
-- when the level actually lands, so this forecast and that screen name the same houses in the same
-- order and the sheet predicts that screen exactly.
--
-- A CLASS key has no discipline blueprint and is title-cased; a discipline uses its display name, so a
-- renamed-away id reads as a slug rather than vanishing silently from a list about growth.
function Party.growthShares(char)
    if not char then return {} end
    local since = Growth.sinceLevel(char)
    if not next(since) then return {} end

    local ranked = {}
    for key, share in pairs(Growth.shares(char)) do
        if share > 0 then
            ranked[#ranked + 1] = { key = key, name = classLabel(key), share = share }
        end
    end
    table.sort(ranked, function(a, b)
        if a.share ~= b.share then return a.share > b.share end
        return a.key < b.key
    end)
    return ranked
end

-- Those claims as the text the sheet prints, biggest first: { "33% Alchemist", "25% Hunter", ... }.
-- Rounded for reading, so the printed percentages can sum to 99 or 101 -- naming the split is the job
-- here, and the arithmetic that matters already happened in Growth.applyLevelBlend. Split out of the
-- draw so the rounding is testable and the caller is left with only the question it needs a font to
-- answer: how many of these terms the 300px column actually fits.
function Party.growthParts(char)
    local parts = {}
    for _, row in ipairs(Party.growthShares(char)) do
        parts[#parts + 1] = math.floor(row.share * 100 + 0.5) .. "% " .. row.name
    end
    return parts
end

-- The member's technique ledger as sorted rows, biggest claim first: { name, share, available }.
--
-- ONE list, where there were two. This panel used to stack a class-usage tally over a technique block,
-- and they were near-impossible to tell apart: both per-character, both ranked name-and-number, and
-- filed under the SAME KEYS -- a member playing assassin gear carried `classUse.assassin` and
-- `technique.assassin`, two unrelated numbers under one word. They are one ledger now
-- (Character.recordTechnique), so they are one list with the two readings that are actually live.
--
-- ONE NUMBER PER HOUSE, and it is the bank: earned under that house, less what the Forge has billed.
--
-- The percentages are gone from here, and so are the column heads that named them. That pairing went
-- through every arrangement it had -- two columns with heads, then a sentence up beside the member's
-- name, then back -- and the answer was that the second number was never worth its keep. A bank of 50
-- Hunter against 16 Alchemist already tells a player which house this body has been living in; the
-- percentage restated the same standing in a second unit, and every attempt to label the two apart cost
-- a header row, a partitive, and a paragraph of explanation. A list of houses ranked by a plain number
-- needs none of that.
--
-- NOT THE CAREER TOTAL. `char.technique` is cumulative and no decision reads it; this is the figure the
-- Forge actually bills. Per-body on purpose even though Discipline.techniqueHolder bills the roster's
-- STRONGEST holder rather than any particular character: this sheet is where you find out who that is.
--
-- A CLASS key has no discipline blueprint and is title-cased; a discipline uses its display name, so a
-- renamed-away id reads as a slug rather than vanishing silently from a list about growth.
--
-- Pure and static (no panel, no love.graphics), so it is unit-testable -- see tests/party_spec.lua,
-- alongside Party.regionCross and Party.equipDelta.
function Party.techniqueRows(char)
    if not char then return {} end

    local rows = {}
    for key in pairs(char.technique or {}) do
        local available = Character.techniqueAvailable(char, key)
        if available > 0 then
            rows[#rows + 1] = { name = classLabel(key), available = available }
        end
    end

    table.sort(rows, function(a, b)
        if a.available ~= b.available then return a.available > b.available end
        return a.name < b.name
    end)
    return rows
end

function Party.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Party)
    self.onClose = opts.onClose
    self.player = opts.player
    self.title = opts.title or "Loadout"
    -- Fired once whenever a stash item is equipped onto a member (a click/confirm or a drag that
    -- lands in the grid). The flight tutorial uses it to clear the "equip an item" coach the moment
    -- the lesson is done, rather than waiting for the panel to close.
    self.onEquip = opts.onEquip

    -- Opt-in / opt-out extras, at their shipped defaults for the Loadout screen (states/hub.lua,
    -- states/game.lua):
    --   stats    (opt-in) add the blueprint field editor tab (states/debug_editor.lua)
    --   tactics  (opt-out, default on) the rule-editor tab; the flight tutorial passes false so the
    --            Tactics tab stays hidden until the player has reached the hub city and it is taught
    --   persist  false to skip the Player.save() on close -- a synthetic player must never be able
    --            to overwrite the real save
    --   filters  a chip strip above the stash; see Party:drawFilters
    self.modes = { "loadout" }
    if opts.tactics ~= false then self.modes[#self.modes + 1] = "tactics" end
    if opts.stats then self.modes[#self.modes + 1] = "stats" end
    self.persist = opts.persist ~= false
    self.filters = opts.filters
    self.onFilterChanged = opts.onFilterChanged
    self.filterCursor = 1
    self.filterOpen = false -- the stash filter dropdown starts closed, behind its "Filter" toggle

    self.titleFont = require("ui.theme").display(28)
    self.headFont = require("ui.theme").display(18)
    self.bodyFont = require("ui.theme").body(15)
    self.smallFont = require("ui.theme").body(13)
    self.tinyFont = require("ui.theme").body(11)

    self.boxX = Scale.WIDTH / 2 - BOX_W / 2
    self.boxY = Scale.HEIGHT / 2 - BOX_H / 2

    self.chars = (self.player and self.player.roster) or {}
    self.charIndex = 1
    self.railOffset = 0
    self.railCursor = 1 -- rail navigation cursor (distinct from charIndex, the edited member)
    self.focus = "grid"
    self.axisActive = false -- analog-stick edge-detect flag (one nav step per push)
    self.axisThreshold = 0.5
    self.drag = nil
    self.quantityPopup = nil
    self.mx, self.my = 0, 0

    self.mode = "loadout"

    -- Layout: rail (left) | focus sheet | member grid | stash pool.
    --
    -- The tab strip claims a band under the title, so `contentY` is derived from it rather than being
    -- a hand-tuned constant -- every column below hangs off this one number, and moving the strip
    -- must not require finding four other offsets.
    self.modeY = self.boxY + 60
    local contentY = self.modeY + MODE_H + 14
    local bottom = self.boxY + BOX_H - 40
    self.railX = self.boxX + 24
    self.railY = contentY
    self.railW = 96
    self.railH = bottom - contentY
    self.railVisible = math.max(1, math.floor((self.railH + RAIL_GAP) / (RAIL_CELL_H + RAIL_GAP)))

    self.focusX = self.railX + self.railW + 20
    self.focusW = 300

    self.gridLabelY = contentY
    self.grid = InventoryGrid.new({
        x = self.focusX + self.focusW + 20,
        y = contentY + 24,
        char = self.chars[self.charIndex],
    })

    local poolX = self.grid.x + self.grid.gridW + 24
    self.poolHeaderY = contentY
    local poolTop = contentY + 24

    self.pool = PoolGrid.new({
        x = poolX,
        y = poolTop,
        w = self.boxX + BOX_W - 24 - poolX,
        h = bottom - poolTop,
        -- The red corner dot on anything that arrived in the stash and has not been looked at
        -- (Player.markNew). Cleared on a look, and persisted then and there: the Armory is a screen a
        -- player can close by walking out of the city, so a mark cleared here must not come back.
        isNew = function(item)
            return Player.isNew(self.player, Player.NEW_STASH, item and item.id)
        end,
        onSeen = function(item)
            if Player.seeNew(self.player, Player.NEW_STASH, item and item.id) then Player.save() end
        end,
    })
    self.pool:setItems(self.player and self.player.stash or {})

    -- Stash filter dropdown: a "Filter" toggle in the stash header (drawFilterButton) opens a chip
    -- strip -- one chip per weapon type / discipline -- laid out over the top of the stash. The options
    -- are fixed for the panel's lifetime, so the chips are positioned ONCE here; only their visibility
    -- (self.filterOpen) changes at runtime. The strip OVERLAYS the stash rather than reserving a band,
    -- so a closed filter costs the stash no height.
    if self.filters then
        local bw, bh, pad = 96, 20, 8
        self.filterBtn = { x = self.pool.x + self.pool.w - bw, y = self.poolHeaderY - 2, w = bw, h = bh }
        local dx, dy = self.pool.x, self.filterBtn.y + self.filterBtn.h + 4
        local dropBottom = self:layoutFilters(dx + pad, dy + pad, self.pool.w - pad * 2)
        self.dropdownRect = { x = dx, y = dy, w = self.pool.w, h = (dropBottom - dy) + pad }
    end

    -- Tab segments, sized to the label rather than to a share of the box: two words centred over a
    -- 1160px panel would read as a header, not as something you can click.
    self.segRects = {}
    local segW = 130
    for i, m in ipairs(self.modes) do
        self.segRects[m] = { x = self.railX + (i - 1) * (segW + 6), y = self.modeY, w = segW, h = MODE_H }
    end

    -- Debug "All Items" toggle: a development-only pill at the right end of the tab band that swaps
    -- the stash for the full item catalog so any item can be equipped and tested (see setDebugAll).
    -- Laid out and drawn only when Debug.enabled, so a release build never shows it. Suppressed only
    -- when the host rebuilds the stash itself on every filter change (onFilterChanged -- the debug
    -- character editor's catalog restock), where a second catalog switch would fight the first. The
    -- Armory's filters are a non-destructive VIEW over the real stash, so the catalog toggle sits
    -- happily beside them (and just gets narrowed by the same view).
    if Debug.enabled and not self.onFilterChanged then
        local dbgW = 190
        self.debugRect = { x = self.boxX + BOX_W - 24 - dbgW, y = self.modeY, w = dbgW, h = MODE_H }
    end
    self.debugAll = false

    -- Both column editors get the SAME rect: they are alternative views of the area right of the
    -- rail, and one of them being wider than the other would read as the panel resizing on a tab
    -- change.
    local column = {
        x = self.focusX, y = contentY,
        w = self.boxX + BOX_W - 24 - self.focusX,
        h = bottom - contentY,
        char = self.chars[self.charIndex],
        fonts = { head = self.headFont, body = self.bodyFont, small = self.smallFont, tiny = self.tinyFont },
        -- Which rule list the Tactics tab edits: the player's overlay in-game (nil -> the editor's own
        -- default), or the blueprint's `ai` directly in the debug character editor. See ui/tactics_editor.
        ownKey = opts.tacticsOwn,
    }
    self.editors = { tactics = TacticsEditor.new(column) }
    if opts.stats then
        -- Required lazily: the stat editor is debug-only content, and the shipped Loadout screen
        -- should not pay to load it.
        column.onEditName = opts.onEditName
        self.editors.stats = require("ui.stat_editor").new(column)
    end
    -- Kept for the existing call sites that name the rule editor directly.
    self.tactics = self.editors.tactics

    self.closeButton = CloseButton.new(self.boxX + BOX_W, self.boxY)
    return self
end

-- The widget owning the whole area right of the rail on the current tab, or nil on `loadout` (where
-- the focus sheet / grid / stash share it instead). Every branch that used to ask `mode == "tactics"`
-- asks this instead, so the `stats` tab -- and any later one -- routes without new branches.
function Party:columnEditor()
    return self.editors[self.mode]
end

function Party:setMode(mode)
    if self.mode == mode then return end
    -- Never carry a held item across a tab switch: the hand would still be full on a screen with
    -- nowhere to put it down, and the item would read as lost.
    self.grid:cancelPickup()
    self.pool:cancelPickup()
    self.drag = nil
    self.mode = mode
    self:setFocus(self:columnEditor() and "editor" or "grid")
end

function Party:cycleMode(delta)
    local index = 1
    for i, m in ipairs(self.modes) do if m == self.mode then index = i end end
    self:setMode(self.modes[(index - 1 + delta) % #self.modes + 1])
end

function Party:setMsg(text, ok)
    self.message, self.messageOk = text, ok
end

function Party:close()
    -- Put the real stash back before anything can persist it: with the debug catalog still installed,
    -- the save below would write hundreds of catalog items over the player's real inventory.
    if self.debugAll then self:setDebugAll(false) end
    -- Persist on the way out, as ui/panels/shop.lua and ui/panels/forge.lua already do. This
    -- screen never used to save at all -- loadout edits (and the default-action star) survived only
    -- until the next unrelated save point. That was survivable when the whole screen was item
    -- placement; it is not once a player has spent minutes writing a rule list, so the save lands
    -- here and covers both.
    --
    -- `persist` is false for a host driving a SYNTHETIC player (the debug character editor), where
    -- saving would write a fabricated roster over the player's real one.
    if self.persist and self.player and Player.save then Player.save() end
    if self.onClose then self.onClose() end
end

function Party:currentChar()
    return self.chars[self.charIndex]
end

function Party:switchChar(delta)
    if #self.chars == 0 then return end
    self.charIndex = (self.charIndex - 1 + delta) % #self.chars + 1
    self.railCursor = self.charIndex
    self:setEditedChar()
    self.pool:cancelPickup()
    self.drag = nil
    self:railScrollToFocus()
end

function Party:focusChar(i)
    if not self.chars[i] then return end
    self.charIndex = i
    self.railCursor = i
    self:setEditedChar()
    self:railScrollToFocus()
end

-- Point every per-member widget at the focused character. One writer, so a newly added editor can't
-- be left showing the previous member on half the tabs.
function Party:setEditedChar()
    local char = self:currentChar()
    self.grid:setChar(char)
    for _, editor in pairs(self.editors) do editor:setChar(char) end
end

-- Single writer for the focused region, keeping the pool's cursor-highlight flag in sync (PoolGrid
-- only draws its cursor when focused). Every focus change -- nav, cycle, mouse -- goes through here.
function Party:setFocus(region)
    self.focus = region
    self.pool.focused = (region == "pool")
    -- The filter dropdown IS the "filters" region: it is open exactly while focused, so Tabbing to it
    -- (or clicking a chip) opens it and moving away closes it, with no separate open flag to desync.
    if self.filters then self.filterOpen = (region == "filters") end
end

-- Region-cycle fallback (Tab / Y): advance through REGIONS and drop any in-progress pickup.
--
-- On a column-editor tab there are only two stops that matter -- the rail and the editor -- and the
-- editor has regions of its own, so Tab hands off INTO it rather than past it and walks those first.
-- The editor says when that walk has run off its end (cycleRegion returns false, having already
-- wrapped back to its first region); focus leaves only then, which keeps Tab feeling like one
-- continuous walk rather than two nested loops fighting for the key -- and lets an editor grow a third
-- region without this knowing its name.
function Party:cycleFocus(delta)
    local editor = self:columnEditor()
    if editor then
        if self.focus == "editor" then
            if not editor:cycleRegion(delta) then self:setFocus("rail") end
        else
            self:setFocus("editor")
        end
        return
    end

    -- The stash filter strip is a Tab stop rather than a left/right one: inside it, left/right
    -- CHANGES a filter's value (as in the rule editor's field column), so it has no free horizontal
    -- axis to cross a region boundary on.
    local regions = REGIONS
    if self.filters then
        regions = { "rail", "grid", "pool", "filters" }
    end
    local idx = 1
    for i, r in ipairs(regions) do if r == self.focus then idx = i break end end
    self:setFocus(regions[(idx - 1 + delta) % #regions + 1])
    self.grid:cancelPickup()
    self.pool:cancelPickup()
    self.drag = nil
end

-- ---------------------------------------------------------------------------
-- Rail (vertical, scrollable roster of portraits)
-- ---------------------------------------------------------------------------

-- Scroll the rail so 0-based `row` sits in the visible window.
function Party:railScrollTo(row)
    if row < self.railOffset then
        self.railOffset = row
    elseif row >= self.railOffset + self.railVisible then
        self.railOffset = row - self.railVisible + 1
    end
    self.railOffset = math.max(0, math.min(math.max(0, #self.chars - self.railVisible), self.railOffset))
end

function Party:railScrollToFocus()
    self:railScrollTo(self.charIndex - 1)
end

-- Move the rail navigation cursor, clamped, keeping it on screen (mirrors PoolGrid:moveCursor).
function Party:moveRailCursor(delta)
    if #self.chars == 0 then return end
    self.railCursor = math.max(1, math.min(#self.chars, self.railCursor + delta))
    self:railScrollTo(self.railCursor - 1)
end

function Party:railRect(i)
    local visRow = (i - 1) - self.railOffset
    if visRow < 0 or visRow >= self.railVisible then return nil end
    return self.railX, self.railY + visRow * (RAIL_CELL_H + RAIL_GAP), self.railW, RAIL_CELL_H
end

function Party:railIndexAt(x, y)
    for i = 1, #self.chars do
        local rx, ry, rw, rh = self:railRect(i)
        if rx and x >= rx and x <= rx + rw and y >= ry and y <= ry + rh then return i end
    end
    return nil
end

function Party:railContains(x, y)
    return x >= self.railX and x <= self.railX + self.railW
        and y >= self.railY and y <= self.railY + self.railH
end

-- Is `char` one of the units currently FIELDED, as opposed to merely owned? (Shown as a badge; not
-- editable here.) Only a caller that actually splits its units into a fielded set and a bench supplies
-- `player.party` -- in practice the draft's synthetic player (states/draft.lua). The campaign has no
-- such split: its roster IS its company and the field is picked per battle, so nothing is badged.
function Party:isFielded(char)
    for _, m in ipairs(self.player and self.player.party or {}) do
        if m == char then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Transfers -- item movement only, no gold (buying/selling is the shop's job).
-- ---------------------------------------------------------------------------

function Party:refreshStash()
    self.pool:setItems(self:visibleStash())
end

-- Does `item` survive the active filter strip? An item passes a group when that group either isn't a
-- view filter (no `valueOf` -- the debug editor's groups filter by rebuilding the catalog instead) or
-- has nothing picked, OR the item's value for the group is one of the picked options. It must pass
-- EVERY group, so "Weapon: sword" + "Discipline: duelist" narrows to swords that are also duelist gear.
function Party:passesFilters(item)
    if not self.filters then return true end
    for _, f in ipairs(self.filters) do
        if f.valueOf and next(f.selected or {}) ~= nil then
            local v = f.valueOf(item)
            if not (v ~= nil and f.selected[v]) then return false end
        end
    end
    return true
end

-- The stash as the pool should show it: the whole list when nothing narrows it, else only the items
-- passing the strip. Building the view also records self.stashMap (pool index -> real stash index) so
-- every transfer can translate back -- the REAL player.stash is never reordered or thinned by a filter,
-- which is what keeps the direct-index transfer paths (Party:placeIntoGrid) handing out the right item.
function Party:visibleStash()
    local stash = (self.player and self.player.stash) or {}
    if not self.filters then self.stashMap = nil return stash end
    local view, map = {}, {}
    for i, item in ipairs(stash) do
        if self:passesFilters(item) then
            view[#view + 1] = item
            map[#view] = i
        end
    end
    self.stashMap = map
    return view
end

-- Translate a POOL cell index into its index in the real player.stash: identity when the pool shows
-- the whole stash (self.stashMap nil), a lookup when a filter is narrowing the view.
function Party:stashIndex(poolIndex)
    if self.stashMap then return self.stashMap[poolIndex] end
    return poolIndex
end

-- ---------------------------------------------------------------------------
-- Debug "All Items" (development only; guarded by Debug.enabled at every seam)
-- ---------------------------------------------------------------------------
--
-- When on, the stash becomes the whole item catalog, restocked to full as it is spent (see
-- restockCatalog), so any item can be dragged onto a member and tried out. It works by SETTING ASIDE
-- the real stash and pointing player.stash at a throwaway catalog buffer -- every transfer path here
-- indexes player.stash directly, so the buffer has to *be* the stash for the duration rather than a
-- view beside it (the same shape states/debug_editor.lua uses for its synthetic player).
--
-- The real stash is restored the instant the toggle goes off OR the panel closes (before any save),
-- so the catalog can never be persisted over the player's real inventory. Items equipped onto members
-- while it was on stay equipped -- that is the point -- but anything left sitting in the catalog
-- buffer, including a real item stowed there while it was on, is discarded with the buffer.
function Party:setDebugAll(on)
    if not Debug.enabled or on == self.debugAll then return end
    -- Never carry a pickup across the swap: its index would point into the wrong list afterward.
    self.grid:cancelPickup()
    self.pool:cancelPickup()
    self.drag = nil

    if on then
        self.realStash = self.player and self.player.stash
        if self.player then self.player.stash = {} end
        self.debugAll = true
        self:restockCatalog()
    else
        if self.player and self.realStash then self.player.stash = self.realStash end
        self.realStash = nil
        self.debugAll = false
        self.pool:setItems(self.player and self.player.stash or {})
        self:refreshStash()
    end
    Debug.allItems = self.debugAll
end

-- Fill the catalog buffer with one full stack of every item, sorted by id so the grid does not
-- reshuffle under the cursor between restocks. Rebuilt in place (same table identity) because the
-- pool holds a reference to player.stash. Mirrors states/debug_editor.lua's restock.
function Party:restockCatalog()
    local stash = self.player and self.player.stash
    if not stash then return end
    local ids = {}
    for id in pairs(Item.defs) do ids[#ids + 1] = id end
    table.sort(ids)
    for i = #stash, 1, -1 do stash[i] = nil end
    for _, id in ipairs(ids) do
        local def = Item.defs[id]
        stash[#stash + 1] = Item.instantiate(id, Item.isStackable(def) and Item.maxStack(def) or 1)
    end
    self.pool:setItems(stash)
    self:refreshStash()
end

-- Restocking while an item is in hand would renumber the buffer under a live pickup, so the catalog
-- only tops up between actions -- invisible in practice, since there is no moment you are both
-- holding something and looking for more of it.
function Party:catalogIdle()
    return self.drag == nil and not self.pool.picked and not self.grid.picked and not self.quantityPopup
end

function Party:toggleDebugAll()
    self:setDebugAll(not self.debugAll)
end

function Party:debugHit(x, y)
    local r = self.debugRect
    return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

-- A screen-space rect over the stash's FIRST ROW OF ITEMS, for the overworld tutorial to pin its
-- "equip an item" coach bubble to (states/game.lua). The stash is where the just-found loot lands and
-- where an equip begins, so it is the thing to point at. Framed to the items actually present (not the
-- pool's full width), so a half-empty stash still centres the bubble over the loot rather than the
-- empty cells to its right. Nil-guarded for a frame before layout has run.
function Party:coachAnchor()
    local p = self.pool
    if not p then return nil end
    local x, y, w, h = p:cellRect(1) -- top-left cell, where the first item sits
    local inRow = math.min(math.max(p:count(), 1), p.cols)
    local lastX = p:cellRect(inRow) -- x of the last filled cell in the first row
    return { x = x, y = y, w = (lastX + w) - x, h = h }
end

-- Say so when `item` has just landed somewhere it will not work: on a body whose pools can never meet
-- its price (Combat.unpayableCosts -- a mana-priced staff given to a fighter, a Counter-Magic charm on
-- a knight), or in a cell with nothing beside it to answer what it requires (Combat.adjacencyGap -- a
-- Rain of Arrows dropped in the first free slot, three cells from the bow).
--
-- The item is still handed over: this screen warns, it does not refuse. Nothing in the game stops you
-- arming somebody badly, and a silent refusal on the one screen for arming people would be worse than
-- the silence this replaces. The adjacency case is not even a mistake yet -- the auto-equip takes the
-- first empty cell, so it is often just the next thing to do -- which is exactly why it is a line of
-- text and not a rejection.
--
-- PRICE FIRST when both are wrong, because only one of them can be acted on here. A cell can be moved;
-- a ceiling cannot, so the shortfall is the one that decides whether this body should carry the item
-- at all.
--
-- Called from EVERY path that lands an item on a member, rather than from one funnel, because there
-- isn't one -- a cell drop, an auto-equip, a stack merge and a drag onto a rail portrait each write the
-- inventory themselves. Returns true when it warned, so a caller with a success message of its own
-- knows this one has taken the line.
function Party:noteUnusable(char, item)
    if not (char and item) then return false end
    local fault = Combat.unpayableCosts(char, item)[1] or Combat.adjacencyGap(char, item)
    if not fault then return false end
    self:setMsg((item.name or "That item") .. ": " .. fault.text .. ".", false)
    return true
end

-- STASH -> current grid cell. Index into the pool maps 1:1 to the stash, since the pool was fed
-- player.stash directly.
function Party:placeIntoGrid(stashIndex, cell)
    local char = self:currentChar()
    if not (char and self.player) then return end
    if Item.isBound(char.inventory[cell]) then return end -- a bound relic can't be displaced from its cell
    local incoming = Player.takeFromStash(self.player, stashIndex)
    if not incoming then return end
    local displaced = char.inventory[cell]
    char.inventory[cell] = incoming
    if displaced then Player.addToStash(self.player, displaced) end
    self:refreshStash()
    self:noteUnusable(char, incoming)
    if self.onEquip then self.onEquip() end -- a stash item just moved onto a member
end

function Party:stashIndexOf(item)
    for i, it in ipairs((self.player and self.player.stash) or {}) do
        if it == item then return i end
    end
    return nil
end

function Party:transferStashToGrid(poolIndex, cell)
    local stashIndex = self:stashIndex(poolIndex)
    local stashItem = self.player and self.player.stash and self.player.stash[stashIndex]
    if not stashItem then return end
    if Item.isStackable(stashItem) and (stashItem.quantity or 1) > 1 then
        self:openQuantityPopup(stashItem, cell)
    else
        self:commitStashToGrid(stashItem, cell, stashItem.quantity or 1)
    end
end

-- Move `count` of a stash item onto the current character, merging into an existing same-id stack
-- first and only spilling the leftover into a cell.
function Party:commitStashToGrid(stashItem, cell, count)
    local char = self:currentChar()
    if not (char and self.player and stashItem) then return end

    if not Item.isStackable(stashItem) then
        local index = self:stashIndexOf(stashItem)
        if index then self:placeIntoGrid(index, cell) end
        return
    end

    count = math.max(1, math.min(count or stashItem.quantity, stashItem.quantity))

    local hadExisting = false
    for i = 1, Character.MAX_INVENTORY do
        local existing = char.inventory[i]
        if existing and existing.id == stashItem.id and Item.isStackable(existing) then
            hadExisting = true
            break
        end
    end

    local remaining = count
    for i = 1, Character.MAX_INVENTORY do
        local existing = char.inventory[i]
        if existing and existing.id == stashItem.id and Item.isStackable(existing) then
            local room = Item.maxStack(existing) - existing.quantity
            if room > 0 then
                local moved = math.min(room, remaining)
                existing.quantity = existing.quantity + moved
                remaining = remaining - moved
                if remaining <= 0 then break end
            end
        end
    end

    if remaining > 0 then
        local slot = hadExisting and Character.firstEmptySlot(char) or cell
        if slot and Item.isBound(char.inventory[slot]) then slot = nil end -- never overwrite a bound relic
        if slot then
            local displaced = char.inventory[slot]
            char.inventory[slot] = Item.instantiate(stashItem.id, remaining, stashItem.level)
            remaining = 0
            if displaced then Player.addToStash(self.player, displaced) end
        end
    end

    local moved = count - remaining
    stashItem.quantity = stashItem.quantity - moved
    if stashItem.quantity <= 0 then
        local index = self:stashIndexOf(stashItem)
        if index then Player.takeFromStash(self.player, index) end
    end

    self.pool:cancelPickup()
    self:refreshStash()
    if moved > 0 then self:noteUnusable(char, stashItem) end
    if moved > 0 and self.onEquip then self.onEquip() end -- some of the stack reached the grid
end

function Party:openQuantityPopup(stashItem, cell)
    self.quantityPopup = QuantityPopup.new({
        max = stashItem.quantity,
        value = stashItem.quantity,
        title = "Move how many?",
        label = stashItem.name,
        onConfirm = function(n)
            self.quantityPopup = nil
            self:commitStashToGrid(stashItem, cell, n)
        end,
        onCancel = function()
            self.quantityPopup = nil
            self.pool:cancelPickup()
        end,
    })
end

-- Send the grid item in `cell` out to the stash.
function Party:stowFromGrid(cell)
    local char = self:currentChar()
    if not (char and self.player) then return end
    local item = char.inventory[cell]
    if not item then return end
    if Item.isBound(item) then self.grid:cancelPickup() return end -- a bound relic never leaves the grid
    Character.removeItem(char, item)
    Player.addToStash(self.player, item)
    self.grid:cancelPickup()
    self:refreshStash()
end

-- Drop the held grid/pool item onto rail portrait `memberIdx` -> give it to that member.
function Party:giveGridItemToMember(cell, memberIdx)
    local member = self.chars[memberIdx]
    local char = self:currentChar()
    if not (member and char) then return end
    if member == char then self.grid:cancelPickup() return end
    local item = char.inventory[cell]
    if not item then return end
    if Item.isBound(item) then self.grid:cancelPickup() return end -- a bound relic can't be given away
    Character.removeItem(char, item)
    if not Character.addItem(member, item) then
        -- No room: return it to where it came from (its cell just freed up).
        Character.addItem(char, item)
        self:setMsg((member.name or "That member") .. "'s grid is full.", false)
    elseif not self:noteUnusable(member, item) then
        -- The warning takes the line when there is one: "Gave X to Y" is the less useful half of what
        -- just happened, and the player watched the item land anyway.
        self:setMsg("Gave " .. (item.name or "item") .. " to " .. (member.name or "member") .. ".", true)
    end
    self.grid:cancelPickup()
end

function Party:givePoolItemToMember(poolIndex, memberIdx)
    local member = self.chars[memberIdx]
    if not member then return end
    local stashIndex = self:stashIndex(poolIndex)
    local item = self.player and self.player.stash and self.player.stash[stashIndex]
    if not item then return end
    Player.takeFromStash(self.player, stashIndex)
    if not Character.addItem(member, item) then
        Player.addToStash(self.player, item)
        self:setMsg((member.name or "That member") .. "'s grid is full.", false)
    elseif not self:noteUnusable(member, item) then
        self:setMsg("Gave " .. (item.name or "item") .. " to " .. (member.name or "member") .. ".", true)
    end
    self.pool:cancelPickup()
    self:refreshStash()
end

-- Confirm on a grid cell: land a held stash item, else pick/swap within the grid.
function Party:activateGrid(cell)
    if self.pool.picked then
        self:transferStashToGrid(self.pool.picked, cell)
    else
        self.grid:activate(cell)
    end
end

-- Confirm on a pool cell: stow a held grid item, else EQUIP the stash item to the focused member.
function Party:activatePool(index)
    if self.grid.picked then
        self:stowFromGrid(self.grid.picked)
    else
        self:equipStashItem(index)
    end
end

-- True if `stashItem` is a stackable an existing same-id stack on `char` still has room to absorb --
-- so it can be equipped even when every grid cell is occupied.
function Party:canMergeStack(char, stashItem)
    if not Item.isStackable(stashItem) then return false end
    for i = 1, Character.MAX_INVENTORY do
        local existing = char.inventory[i]
        if existing and existing.id == stashItem.id and Item.isStackable(existing)
            and existing.quantity < Item.maxStack(existing) then
            return true
        end
    end
    return false
end

-- Auto-equip a whole stash item onto the focused member's first empty slot (stackables merge into an
-- existing same-id stack first). This is what a plain click / confirm on a stash cell does; a mouse
-- drag onto a specific cell or portrait is the way to aim a slot, member, or a partial quantity.
function Party:equipStashItem(poolIndex)
    local char = self:currentChar()
    local stashItem = self.player and self.player.stash and self.player.stash[self:stashIndex(poolIndex)]
    if not (char and stashItem) then return end
    local slot = Character.firstEmptySlot(char)
    if not slot and not self:canMergeStack(char, stashItem) then
        self:setMsg((char.name or "This character") .. "'s inventory is full.", false)
        return
    end
    self:commitStashToGrid(stashItem, slot, stashItem.quantity or 1)
end

-- ---------------------------------------------------------------------------
-- Unified navigation -- one cursor flowing across the three regions. Keyboard, D-pad, and the
-- analog stick all funnel through navigate/confirm so the three input paths can't desync.
-- ---------------------------------------------------------------------------

-- Pure edge-crossing rule: at column `col` of `cols`, pushed horizontally by `dc`, which region
-- (if any) does the cursor move into? Rail is leftmost and Stash rightmost, so those outer edges
-- clamp. Returns the target region, or nil to stay and move within the current one.
function Party.regionCross(region, col, cols, dc)
    if region == "grid" then
        if dc == -1 and col == 0 then return "rail" end
        if dc == 1 and col == cols - 1 then return "pool" end
    elseif region == "pool" then
        if dc == -1 and col == 0 then return "grid" end
    elseif region == "rail" then
        if dc == 1 then return "grid" end
    end
    return nil
end

-- One navigation step. A horizontal press at a column edge crosses to the neighbour region
-- (and does not also move within it); otherwise the focused widget moves its own cursor.
function Party:navigate(dc, dr)
    local region = self.focus
    if region == "editor" then
        -- The editor owns both axes: left/right cycles a field's value rather than crossing regions,
        -- so the only way back out is Tab. Pushing left from its first region crosses to the rail,
        -- which keeps the rail reachable without a modifier.
        local editor = self:columnEditor()
        if dc == -1 and editor:isFirstRegion() then self:setFocus("rail") return end
        editor:navigate(dc, dr)
        return
    end
    if region == "filters" then
        -- The chips are a small grid of their own, so all four directions just move the cursor and
        -- confirm toggles. Pushing left off the first chip in a row leaves for the stash, which is
        -- what the strip filters.
        local chip = self.filterChips[self.filterCursor]
        if dc == -1 and chip and chip.col == 1 then self:setFocus("pool") return end
        self:moveFilterCursor(dc, dr)
        return
    end
    if dc ~= 0 then
        local col, cols
        if region == "grid" then
            col, cols = (self.grid.cursor - 1) % Character.COLS, Character.COLS
        elseif region == "pool" then
            col, cols = (self.pool.cursor - 1) % self.pool.cols, self.pool.cols
        elseif region == "rail" and self:columnEditor() then
            -- A column-editor tab has no grid to cross into; the rail's right edge lands in the editor.
            if dc == 1 then self:setFocus("editor") return end
            col, cols = 0, 1
        else -- rail is a single column
            col, cols = 0, 1
        end
        local target = Party.regionCross(region, col, cols, dc)
        if target then self:setFocus(target) return end
    end
    if region == "grid" then
        self.grid:moveCursor(dc, dr)
    elseif region == "pool" then
        self.pool:moveCursor(dc, dr)
    else
        self:moveRailCursor(dr)
    end
end

-- Confirm (A / Enter) on the focused region. On the rail this is where cross-member GIVE is
-- reached on a pad: a held item goes to the cursored portrait; empty-handed, it focuses them.
function Party:confirm()
    if self.focus == "editor" then
        self:columnEditor():confirm()
        return
    end
    if self.focus == "filters" then
        self:toggleFilter(self.filterCursor)
        return
    end
    if self.focus == "rail" then
        if self.grid.picked then
            self:giveGridItemToMember(self.grid.picked, self.railCursor)
        elseif self.pool.picked then
            self:givePoolItemToMember(self.pool.picked, self.railCursor)
        else
            self:focusChar(self.railCursor)
        end
    elseif self.focus == "pool" then
        self:activatePool(self.pool.cursor)
    else
        self:activateGrid(self.grid.cursor)
    end
end

-- ---------------------------------------------------------------------------
-- Stash filters (optional; supplied by the host, see opts.filters)
-- ---------------------------------------------------------------------------
--
-- A filter is { label = "Type", options = { "weapon", ... }, selected = {} }. Every option is its
-- own TOGGLE chip rather than a step in a cycler: the two questions the stash asks ("which types?",
-- "which classes?") are answered by picking a handful, and a cycler makes that a hunt through a list
-- that only ever shows one answer at a time. `selected` is a set of option -> true; EMPTY means no
-- restriction, so an untouched strip shows the whole stash and there is no separate "All" entry to
-- keep in sync with the chips.
--
-- The panel owns the chips, the cursor, and the toggling; the HOST owns what a filter means -- it
-- rebuilds the backing stash list in `onFilterChanged` and the pool is refreshed from it.
--
-- Filtering deliberately happens in that backing list rather than as a view over PoolGrid: every
-- transfer path here indexes the stash directly (see Party:placeIntoGrid), so a pool showing a
-- filtered subset at different indices would hand out the wrong item.

local CHIP_H = 20
local CHIP_GAP = 4
local CHIP_PAD = 8

-- Flow every group's chips into the band, wrapping at `w`, and record the grid they landed on
-- (row/col per chip) so keyboard and pad navigation can walk the ragged rows. Returns the y the band
-- ends at. Each group's label sits inline at the left of its first row, so the strip stays two short
-- blocks rather than a stack of headers eating the stash's height.
-- The words a chip shows. `option` is the stored VALUE (a raw archetype id, a discipline id) the
-- filter matches on and keys `selected` by; `format` (optional) prettifies it for display only --
-- "trapper" -> "Trapper" -- so nice labels never change what the filter actually compares.
function Party:chipLabel(filter, option)
    return (filter.format and filter.format(option)) or option
end

function Party:layoutFilters(x, y, w)
    love.graphics.setFont(self.tinyFont)
    local labelW = 0
    for _, filter in ipairs(self.filters) do
        labelW = math.max(labelW, self.tinyFont:getWidth(filter.label) + 10)
    end

    self.filterLabelX = x
    self.filterChips = {}
    local chipX0 = x + labelW
    local cx, cy, row, col = chipX0, y, 1, 0

    for gi, filter in ipairs(self.filters) do
        filter.selected = filter.selected or {}
        if gi > 1 then -- each group starts its own row
            if col > 0 then cy = cy + CHIP_H + CHIP_GAP; row = row + 1 end
            cx, col = chipX0, 0
        end
        filter.labelY = cy
        for _, option in ipairs(filter.options) do
            local cw = self.tinyFont:getWidth(self:chipLabel(filter, option)) + CHIP_PAD * 2
            if col > 0 and cx + cw > x + w then
                cx, cy, col, row = chipX0, cy + CHIP_H + CHIP_GAP, 0, row + 1
            end
            col = col + 1
            self.filterChips[#self.filterChips + 1] = {
                group = gi, option = option, row = row, col = col,
                x = cx, y = cy, w = cw, h = CHIP_H,
            }
            cx = cx + cw + CHIP_GAP
        end
    end

    self.filterCursor = 1
    return cy + CHIP_H
end

-- Show / hide the filter dropdown. Open and "the filters region is focused" are the same state (see
-- setFocus), so opening is just focusing the region and closing is handing focus back to the stash.
function Party:toggleFilterPanel()
    if self.filterOpen then self:closeFilterPanel() else self:openFilterPanel() end
end

function Party:openFilterPanel()
    self.grid:cancelPickup()
    self.pool:cancelPickup()
    self.drag = nil
    self:setFocus("filters")
end

function Party:closeFilterPanel()
    if self.focus == "filters" then self:setFocus("pool") else self.filterOpen = false end
end

-- Flip one chip on or off. Toggling never touches the others: a stash filtered to "weapon + armor"
-- is a normal thing to want, and reaching it must not cost a trip through a cycler.
function Party:toggleFilter(i)
    local chip = self.filterChips and self.filterChips[i]
    if not chip then return end
    local filter = self.filters[chip.group]
    filter.selected[chip.option] = (not filter.selected[chip.option]) or nil
    self.pool:cancelPickup()
    if self.onFilterChanged then self.onFilterChanged(self.filters) end
    self:refreshStash()
    -- The list just changed length under the cursor; put it somewhere that exists.
    self.pool.cursor = math.max(1, math.min(math.max(1, self.pool:count()), self.pool.cursor))
end

-- The chip nearest `chip` horizontally in row `row`, or nil if that row is off the strip. Rows are
-- ragged (chips are label-width), so "the same column" would skip about; centre distance doesn't.
function Party:filterChipInRow(row, chip)
    local best, bestDist
    local cx = chip.x + chip.w / 2
    for _, other in ipairs(self.filterChips) do
        if other.row == row then
            local d = math.abs((other.x + other.w / 2) - cx)
            if not bestDist or d < bestDist then best, bestDist = other, d end
        end
    end
    return best
end

function Party:moveFilterCursor(dc, dr)
    local chip = self.filterChips[self.filterCursor]
    if not chip then return end
    local target
    if dr ~= 0 then
        target = self:filterChipInRow(chip.row + dr, chip)
    else
        for _, other in ipairs(self.filterChips) do
            if other.row == chip.row and other.col == chip.col + dc then target = other end
        end
    end
    if not target then return end
    for i, other in ipairs(self.filterChips) do
        if other == target then self.filterCursor = i return end
    end
end

function Party:filterIndexAt(x, y)
    if not self.filterOpen then return nil end -- chips aren't drawn (or clickable) while the dropdown is shut
    for i, r in ipairs(self.filterChips or {}) do
        if pointIn(r, x, y) then return i end
    end
    return nil
end

-- The "Filter" toggle in the stash header: three burger bars + the word, always shown when the panel
-- has filters. A count rides along ("Filter (2)") whenever any chip is picked, so the strip being shut
-- never hides the fact that the stash is currently narrowed.
function Party:drawFilterButton()
    local r = self.filterBtn
    if not r then return end
    local active = 0
    for _, f in ipairs(self.filters) do
        for _ in pairs(f.selected or {}) do active = active + 1 end
    end
    local open = self.filterOpen
    Theme.set(open and Theme.panel or Theme.panel2)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 5, 5)
    Theme.set(active > 0 and Theme.accentAmber or Theme.frame)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 5, 5)

    local bx, barW = r.x + 8, 12
    Theme.set(Theme.ink)
    for k = 0, 2 do
        love.graphics.rectangle("fill", bx, r.y + 6 + k * 4, barW, 2, 1, 1)
    end
    love.graphics.setFont(self.smallFont)
    Theme.set(Theme.ink)
    local label = active > 0 and ("Filter (" .. active .. ")") or "Filter"
    love.graphics.print(label, bx + barW + 6, r.y + (r.h - self.smallFont:getHeight()) / 2)
    love.graphics.setColor(1, 1, 1)
end

-- The filter dropdown: drawn only while open, as an overlay panel below the Filter toggle (so a shut
-- filter reserves no stash height). Each group prints its label inline, then its wrap-flowed chips.
function Party:drawFilters()
    if not (self.filters and self.filterOpen and self.dropdownRect) then return end
    local r = self.dropdownRect
    Theme.set(Theme.panel) -- fully opaque so the stash beneath doesn't bleed through
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 6, 6)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 6, 6)

    love.graphics.setFont(self.tinyFont)
    local th = self.tinyFont:getHeight()

    for _, filter in ipairs(self.filters) do
        Theme.set(Theme.muted)
        love.graphics.print(filter.label, self.filterLabelX, filter.labelY + (CHIP_H - th) / 2)
    end

    for i, chip in ipairs(self.filterChips) do
        local filter = self.filters[chip.group]
        local on = filter.selected[chip.option]
        local cursored = (self.focus == "filters" and self.filterCursor == i)

        -- On reads as a lit chip, off as a hollow one; the cursor is a separate ring, so a focused
        -- chip still says whether it is selected.
        Theme.set(on and Theme.panel2 or Theme.slot)
        love.graphics.rectangle("fill", chip.x, chip.y, chip.w, chip.h, 4, 4)
        Theme.set(on and Theme.accentAmber or Theme.frame)
        love.graphics.rectangle("line", chip.x, chip.y, chip.w, chip.h, 4, 4)

        if cursored then
            Theme.set(Theme.cursor)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", chip.x - 2, chip.y - 2, chip.w + 4, chip.h + 4, 5, 5)
            love.graphics.setLineWidth(1)
        end

        Theme.set(on and Theme.ink or Theme.muted)
        love.graphics.printf(self:chipLabel(filter, chip.option), chip.x, chip.y + (CHIP_H - th) / 2, chip.w, "center")
    end
    love.graphics.setColor(1, 1, 1)
end

-- ---------------------------------------------------------------------------
-- Equip-delta preview (read-only): how a picked item would change the focused member's stats.
-- ---------------------------------------------------------------------------

-- Is the level forecast showing? True while the pointer is over the "Growing as X" clause, or while the
-- peek is pinned.
--
-- THE PIN IS NOT A LUXURY. Hover alone would make this the one reading on the sheet a pad or a keyboard
-- cannot reach, and three-input is the house rule (ui/menu.lua, ui/building_map.lua). G and gamepad X
-- toggle it; clicking the clause toggles it too, which also gives a mouse user a way to hold the
-- forecast open while they read the whole column instead of freezing their hand over one line.
function Party:growthPeeking()
    if self.growthPeek then return true end
    local r = self.growthRect
    return (r and self.mx and pointIn(r, self.mx, self.my)) or false
end

function Party:toggleGrowthPeek()
    self.growthPeek = not self.growthPeek
end

-- The stat key whose row is under (x, y), or nil -- drives the source tooltip. Rects are stashed by
-- drawFocus, so this answers nil until the sheet has been drawn once.
function Party:statAt(x, y)
    for _, r in ipairs(self.statRects or {}) do
        if pointIn(r, x, y) then return r.key end
    end
    return nil
end

-- The item currently in hand and where it came from ("grid" | "pool"), or nil.
function Party:pickedItem()
    if self.grid.picked then
        local char = self:currentChar()
        return char and char.inventory[self.grid.picked], "grid"
    elseif self.pool.picked then
        return self.pool:itemAt(self.pool.picked), "pool"
    end
    return nil
end

-- What `item` would do to each row of the focus sheet if it were equipped, keyed by stat: the flat
-- bonuses AND the resource-ceiling raises, each read off the field that actually carries it
-- (Character.bonusField). Only rows the sheet prints -- an item's resist bag and its unarmed buffs move
-- nothing here and never leak in.
--
-- THE POOL ROWS USED TO BE FILTERED OUT, on the grounds that HP shows "77/89" rather than a plain number
-- and had nothing an item could move. The first half was never a reason and the second stopped being
-- true the moment the sheet started counting gear toward the ceiling: what was left was a preview that
-- went silent over Toughness, Endurance and Attunement -- the three items whose whole text is the number
-- it was declining to show.
--
-- Pure and static (no Combat, no mutation) so it's unit-testable without constructing a panel.
function Party.equipDelta(item)
    local delta = {}
    if not item then return delta end
    for _, key in ipairs(SHEET_KEYS) do
        local field = Character.bonusField(key)
        local v = item[field] and item[field][key]
        if v and v ~= 0 then delta[key] = v end
    end
    return delta
end

-- Everything feeding one stat on this member (base first, then one row per piece of gear that moves it),
-- and that list summed -- the effective stat with gear folded in, which is the figure the sheet PRINTS.
--
-- Both moved down to models/character.lua, where the body they describe lives: models/muster.lua rates a
-- character by exactly these numbers to weigh a fight against the company, and a model may not require a
-- panel. The names stay here because the sheet is still their loudest reader; see the model for the
-- `bonus` vs `maxBonus` split and why reading the wrong one is silent.
function Party.statSources(char, key)
    return Character.statSources(char, key)
end

function Party.statTotal(char, key)
    return Character.statTotal(char, key)
end

-- Sign of the picked item's effect on the FOCUSED member (the one the sheet shows): a stash item
-- lands on them (+1) unless it's being given to someone else; a grid item leaves them (-1) when
-- stowed or given away. A rearrange within the grid or a give-to-self nets nothing (0).
function Party:deltaSign(source)
    local toOther = (self.focus == "rail" and self.railCursor ~= self.charIndex)
    if source == "pool" then
        return toOther and 0 or 1
    elseif source == "grid" then
        if self.focus == "pool" or toOther then return -1 end
        return 0
    end
    return 0
end

-- ---------------------------------------------------------------------------
-- Dragging (aims an existing pickup; ends by calling the same transfers)
-- ---------------------------------------------------------------------------

function Party:beginDrag(from, index, x, y)
    self.drag = { from = from, index = index, x = x, y = y, startX = x, startY = y, active = false }
end

function Party:dragItem()
    local drag = self.drag
    if not drag then return nil end
    if drag.from == "pool" then return self.pool:itemAt(drag.index) end
    local char = self:currentChar()
    return char and char.inventory[drag.index]
end

function Party:dropDrag(x, y)
    local drag = self.drag
    self.drag = nil
    if not (drag and drag.active) then return end -- a click, not a drag: pickup stays in hand

    local cell = self.grid:indexAt(x, y)
    local ri = self:railIndexAt(x, y)
    if drag.from == "grid" then
        if cell then
            self.grid:activate(cell)
        elseif ri then
            self:giveGridItemToMember(drag.index, ri)
        elseif self.pool:contains(x, y) then
            self:stowFromGrid(drag.index)
        else
            self.grid:cancelPickup()
        end
    else -- from pool
        if cell then
            self:transferStashToGrid(drag.index, cell)
        elseif ri then
            self:givePoolItemToMember(drag.index, ri)
        else
            self.pool:cancelPickup()
        end
    end
end

-- ---------------------------------------------------------------------------
-- Update / draw
-- ---------------------------------------------------------------------------

function Party:update(dt)
    -- Top the debug catalog back up between actions, so an equipped item is instantly replaced.
    if self.debugAll and self:catalogIdle() then self:restockCatalog() end
    if self.quantityPopup then self.quantityPopup:update(dt) return end
    -- Poll the analog stick for navigation, edge-detected so a held stick steps one cell per push
    -- (mirrors ui/battle_map.lua). D-pad is handled directly in gamepadpressed.
    if not love.joystick then return end
    for _, joy in ipairs(love.joystick.getJoysticks()) do
        if joy:isGamepad() then
            local ax, ay = joy:getGamepadAxis("leftx"), joy:getGamepadAxis("lefty")
            local dx, dy = 0, 0
            if ax <= -self.axisThreshold then dx = -1
            elseif ax >= self.axisThreshold then dx = 1
            elseif ay <= -self.axisThreshold then dy = -1
            elseif ay >= self.axisThreshold then dy = 1 end
            if dx == 0 and dy == 0 then
                self.axisActive = false
            elseif not self.axisActive then
                self.axisActive = true
                self:navigate(dx, dy)
            end
        end
    end
end

function Party:draw()
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", self.boxX, self.boxY, BOX_W, BOX_H, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", self.boxX, self.boxY, BOX_W, BOX_H, Theme.R, Theme.R)

    love.graphics.setFont(self.titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf(self.title, self.boxX, self.boxY + 18, BOX_W, "center")

    self:drawModeSelector()
    self:drawDebugToggle()
    self:drawRail()
    local editor = self:columnEditor()
    if editor then
        editor:draw()
    else
        self:drawFocus()
        self:drawMemberGrid()
        self:drawPool()
        self:drawFilterButton()
        self:drawFilters() -- the dropdown, drawn last so it overlays the top of the stash while open
    end

    self:drawFooter()
    self.closeButton:draw()
    self:drawDrag()
    if not self.drag then self:drawActiveTooltip() end
    if self.quantityPopup then self.quantityPopup:draw() end
    love.graphics.setColor(1, 1, 1)
end

function Party:drawRail()
    for i = 1, #self.chars do
        local rx, ry, rw, rh = self:railRect(i)
        if rx then self:drawRailPortrait(self.chars[i], i, rx, ry, rw, rh) end
    end
    -- Vertical scroll hint chevrons when the roster overflows.
    if #self.chars > self.railVisible then
        love.graphics.setFont(self.smallFont)
        Theme.set(Theme.muted, self.railOffset > 0 and 0.9 or 0.2)
        love.graphics.printf("^", self.railX, self.railY - 16, self.railW, "center")
        local maxOff = #self.chars - self.railVisible
        Theme.set(Theme.muted, self.railOffset < maxOff and 0.9 or 0.2)
        love.graphics.printf("v", self.railX, self.railY + self.railH + 2, self.railW, "center")
    end
end

function Party:drawRailPortrait(char, i, rx, ry, rw, rh)
    local focused = (i == self.charIndex)
    Theme.set(focused and Theme.panel or Theme.panel2)
    love.graphics.rectangle("fill", rx, ry, rw, rh, 6, 6)

    local sprite = char.sprite
    local px, py, ps = rx + (rw - PORTRAIT) / 2, ry + 4, PORTRAIT
    if type(sprite) == "userdata" then
        love.graphics.setColor(1, 1, 1)
        local sw, sh = sprite:getDimensions()
        local scale = math.min(ps / sw, ps / sh)
        love.graphics.draw(sprite, px + ps / 2, py + ps / 2, 0, scale, scale, sw / 2, sh / 2)
    else
        Theme.set(Theme.slot)
        love.graphics.rectangle("fill", px, py, ps, ps, 5, 5)
        love.graphics.setFont(self.headFont)
        Theme.set(Theme.ink)
        love.graphics.printf((char.name or "?"):sub(1, 1), px, py + ps / 2 - 12, ps, "center")
    end

    love.graphics.setFont(self.tinyFont)
    Theme.set(Theme.ink)
    love.graphics.printf(char.name or "?", rx + 2, ry + rh - 16, rw - 4, "center")

    if self:isFielded(char) then
        Theme.set(Theme.accentAmber)
        love.graphics.circle("fill", rx + rw - 8, ry + 8, 4)
    end

    -- Warm amber ring marks the EDITED member (whose grid/stats show); the cool cursor ring marks where
    -- rail navigation currently points -- distinct colors so the two never read as one.
    if focused then
        Theme.set(Theme.accentAmber)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", rx, ry, rw, rh, 6, 6)
        love.graphics.setLineWidth(1)
    end
    if self.focus == "rail" and i == self.railCursor then
        Theme.set(Theme.cursor)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", rx - 2, ry - 2, rw + 4, rh + 4, 7, 7)
        love.graphics.setLineWidth(1)
    end
end

-- Focus sheet: the selected member's big portrait, name, and stats (two per row).
function Party:drawFocus()
    local char = self:currentChar()
    if not char then return end
    local x, y = self.focusX, self.boxY + 96

    local ps = 168
    local px = x + (self.focusW - ps) / 2
    Theme.set(Theme.slot)
    love.graphics.rectangle("fill", px, y, ps, ps, 8, 8)
    local sprite = char.sprite
    if type(sprite) == "userdata" then
        love.graphics.setColor(1, 1, 1)
        local sw, sh = sprite:getDimensions()
        local scale = math.min((ps - 12) / sw, (ps - 12) / sh)
        love.graphics.draw(sprite, px + ps / 2, y + ps / 2, 0, scale, scale, sw / 2, sh / 2)
    else
        love.graphics.setFont(self.titleFont)
        Theme.set(Theme.ink)
        love.graphics.printf((char.name or "?"):sub(1, 1), px, y + ps / 2 - 18, ps, "center")
    end
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", px, y, ps, ps, 8, 8)

    love.graphics.setFont(self.headFont)
    Theme.set(Theme.ink)
    love.graphics.printf(char.name or "?", x, y + ps + 6, self.focusW, "center")

    -- Level + what this body is becoming. The level tracks the player's prestige, and each level-up
    -- apportions its stat gains across everything the member has been casting since the last one
    -- (models/growth.lua). The clause names the house leading THAT reading, not the career leader --
    -- see Party.growthShares for why the career title came off this line.
    --
    -- The clause is also a HANDLE. Point at it and the stats below show where that level is taking them
    -- (Party:growthPeeking); its own hit rect is stashed for the hover test and for the click that pins
    -- the peek open. Lit to full ink while it is engaged, so the handle says it is one.
    local growth = Party.growthShares(char)
    love.graphics.setFont(self.smallFont)
    local heading = "Lv " .. tostring(char.level or 1)
    local clause = growth[1] and ("  -  Growing as " .. growth[1].name) or nil
    local hy = y + ps + 30
    self.growthRect = nil
    if clause then
        -- Only the clause is the handle, not the "Lv 4" beside it, so the rect is measured off the
        -- centred line rather than taking the whole width.
        local full = self.smallFont:getWidth(heading .. clause)
        local lead = self.smallFont:getWidth(heading)
        local left = x + (self.focusW - full) / 2
        self.growthRect = { x = left + lead, y = hy - 2,
            w = full - lead, h = self.smallFont:getHeight() + 4 }
    end
    Theme.set(self:growthPeeking() and Theme.ink or Theme.muted)
    love.graphics.printf(heading .. (clause or ""), x, hy, self.focusW, "center")

    -- What the coming level buys, per stat (models/growth.lua). Read every frame and side-effect-free
    -- by construction; see Growth.previewLevel.
    --
    -- SHOWN ONLY WHILE THE HANDLE IS ENGAGED, and as a transition rather than an addition. Both halves
    -- of that were learned the hard way: a permanent green "+3" beside a value is the universal "this
    -- is buffed right now" idiom, and it read as one. (The equip delta gets away with the same glyph
    -- because it exists only while an item is in hand, so it is visibly tied to a gesture.) An arrow to
    -- the value it becomes cannot be read as a bonus already in effect, and gating it on the growth
    -- clause ties it to the sentence that explains it.
    local pending = self:growthPeeking() and Growth.previewLevel(char) or {}

    -- If an item is in hand, preview how it changes THIS member's flat stats (green gain / red
    -- loss). The sheet shows BASE stats -- equipped bonuses aren't folded in, a pre-existing gap --
    -- so this is an additive annotation next to the value, never a recomputation of it.
    local held, heldSource = self:pickedItem()
    local delta = held and Party.equipDelta(held) or nil
    local sign = held and self:deltaSign(heldSource) or 0

    -- Stats, two per row. Each row's rect is stashed for the source tooltip (Party:statAt).
    love.graphics.setFont(self.bodyFont)
    local sy = y + ps + 56
    local colW = self.focusW / 2
    local rowH = self.bodyFont:getHeight()
    local n = 0
    self.statRects = {}
    for _, row in ipairs(STAT_ROWS) do
        local stat = char.stats and char.stats[row.key]
        if stat ~= nil then
            local col = n % 2
            local cx = x + col * colW
            -- The EFFECTIVE figure, gear folded in (Party.statTotal) -- for a resource that is the
            -- ceiling, with `current` left where it is, so a wounded member still reads as wounded.
            local total = Party.statTotal(char, row.key)
            local value
            if row.res and type(stat) == "table" then
                value = (stat.current or total) .. "/" .. total
            else
                value = tostring(total)
            end
            self.statRects[#self.statRects + 1] =
                { key = row.key, x = cx, y = sy - 2, w = colW - 10, h = rowH + 4 }

            Theme.set(Theme.muted)
            love.graphics.print(row.label, cx, sy)

            -- The row's right-hand slot holds ONE of three things, in this order of precedence:
            -- the item in hand's delta (the question the player is actively asking), the level
            -- forecast as an arrow, or just the number.
            local change, tint
            if delta and sign ~= 0 and delta[row.key] and delta[row.key] ~= 0 then
                change = sign * delta[row.key]
                tint = change > 0 and ANNOT_GAIN or ANNOT_LOSS
            end

            if change then
                Theme.set(Theme.ink)
                love.graphics.printf(value, cx, sy, colW - 16, "right")
                local text = (change > 0 and "+" or "") .. change
                love.graphics.setColor(tint)
                local dw = self.bodyFont:getWidth(text)
                local vw = self.bodyFont:getWidth(value)
                love.graphics.print(text, cx + (colW - 16) - vw - 6 - dw, sy)
            elseif (pending[row.key] or 0) > 0 then
                -- "16 → 17", right-aligned as one unit. A resource row moves its CEILING, so the
                -- target is the new max alone -- "77/77 → 80" -- rather than a second pair, which
                -- would not fit the column and would imply the current reading moved too.
                local tail = " " .. ARROW .. " " .. (total + pending[row.key])
                local tw = self.bodyFont:getWidth(tail)
                Theme.set(Theme.ink)
                love.graphics.printf(value, cx, sy, colW - 16 - tw, "right")
                Theme.set(ANNOT_PENDING)
                love.graphics.print(tail, cx + (colW - 16) - tw, sy)
            else
                Theme.set(Theme.ink)
                love.graphics.printf(value, cx, sy, colW - 16, "right")
            end
            n = n + 1
            if col == 1 then sy = sy + 22 end
        end
    end
    if n % 2 == 1 then sy = sy + 22 end

    self:drawTechnique(char, x, sy + 12)
end

-- The technique ledger, under the stats: one house per row, one number each.
--
-- NO COLUMN HEADS, because there is only one column and its rows are already named. The heads existed to
-- keep two unlike numbers apart ("of next lv" against "to spend"); with the percentage gone there is
-- nothing to tell apart, and a lone head over a lone column is a label for a label. The house name and a
-- ranked figure in wallet gold say the whole thing: this is what each house has banked on this body, and
-- the one at the top is the one it has been living in.
--
-- Full-width rows rather than the stats' two columns -- a key is often two words ("Plague Knight"), not
-- "M.Def". Rows are budgeted against the panel floor instead of a fixed cap: seven classes plus 37
-- disciplines is a lot of ground for a long campaign to cover, so the list takes what room is left above
-- the prompt bar and folds the rest into a "+N more" tail rather than drawing through the frame.
function Party:drawTechnique(char, x, y)
    local rows = Party.techniqueRows(char)

    -- The caption doubles as the section's explainer handle (Party:drawTechniqueTooltip): a heading has
    -- no room to say what a currency IS, and "Technique" is the one word on this sheet a new player has
    -- no way to unpack from context.
    love.graphics.setFont(self.smallFont)
    self.techniqueRect = Theme.caption("Technique", x, y, self.focusW)
    y = y + 20

    -- Two empty states, because they are different facts. Nothing earned yet names the VERB that earns
    -- it -- a blank section would read as a broken panel, and this is every member until their first
    -- fight, so it is where the loop gets explained. A ledger that exists but is billed flat is not that
    -- member: telling a veteran who has forged everything to go and learn some technique would read as
    -- the panel having forgotten them.
    if #rows == 0 then
        local earned = false
        for _, amount in pairs(char.technique or {}) do
            if (amount or 0) > 0 then earned = true end
        end
        Theme.set(Theme.muted, 0.8)
        love.graphics.printf(earned
            and "Spent out -- every house here is already forged into something."
            or "None yet -- fight, and every house you carry teaches this body.",
            x, y + 2, self.focusW, "center")
        return
    end

    local spendW = 64                     -- the amber bank, right-aligned against the panel edge
    local nameW = self.focusW - spendW - 20

    local floor = self.boxY + BOX_H - 64 -- above the message line and the prompt bar
    local fit = math.max(1, math.floor((floor - y) / 20))
    local shown = #rows
    if shown > fit then shown = math.max(0, fit - 1) end -- the tail line costs a row

    -- Muted label, accented value -- the same pairing as the stat rows directly above, so a row here
    -- reads as one of them rather than as a third idiom. The figure takes the amber the battle floater
    -- and the Forge chip already use for spendable technique; Theme.cursor is deliberately NOT used,
    -- because that blue means "the selection is here" and spending it on a data column would make every
    -- sheet look navigated.
    love.graphics.setFont(self.bodyFont)
    for i = 1, shown do
        local row = rows[i]
        Theme.set(Theme.muted)
        love.graphics.print(Theme.ellipsize(row.name, self.bodyFont, nameW), x, y)
        Theme.set(Theme.accentAmber)
        love.graphics.printf(tostring(row.available), x + nameW, y, spendW, "right")
        y = y + 20
    end
    if shown < #rows then
        love.graphics.setFont(self.smallFont)
        Theme.set(Theme.muted, 0.8)
        love.graphics.print("+" .. (#rows - shown) .. " more", x, y)
    end
end

-- The focused member's 3x3 grid (the anchor) with the adjacency legend beneath it.
function Party:drawMemberGrid()
    -- What the player is holding over the grid from OUTSIDE it -- a stash item mid-drag, or one
    -- picked up with the keyboard. The grid finds its own pickup on its own; this is the case it
    -- can't see, since the item isn't in the inventory yet. Handing it over lets the grid green-light
    -- the cells where the item's adjacency requirement would be met (a Rain of Arrows lights the
    -- cells touching a bow). Derived at draw time so it tracks every path that fills/empties the
    -- hand -- mouse drag, click, or keyboard pick -- without each one having to remember to say so.
    local incoming
    if self.drag and self.drag.from == "pool" then
        incoming = self:dragItem()
    elseif self.pool.picked then
        incoming = self.pool:itemAt(self.pool.picked)
    end
    self.grid:setHeldItem(incoming)

    love.graphics.setFont(self.smallFont)
    Theme.set(Theme.muted)
    love.graphics.print("Inventory", self.grid.x, self.gridLabelY)
    self.grid:draw()

    local ly = self.grid.y + self.grid.gridH + 16
    love.graphics.setFont(self.bodyFont)
    for _, row in ipairs(LEGEND) do
        local c = AdjacencyLinks.COLOR[row.kind]
        love.graphics.setColor(c[1], c[2], c[3])
        love.graphics.setLineWidth(3)
        love.graphics.line(self.grid.x, ly + 8, self.grid.x + 26, ly + 8)
        love.graphics.setLineWidth(1)
        Theme.set(Theme.ink)
        love.graphics.print(row.label, self.grid.x + 36, ly)
        ly = ly + 24
    end
    -- Default-action star: the same gold mark drawn on an ability cell, so the badge on the grid
    -- reads without hunting for what it means (hover the badge itself for the fuller tooltip).
    InventoryGrid.drawStar(self.grid.x + 13, ly + 8, 8, true)
    Theme.set(Theme.ink)
    love.graphics.print("Default action (click the star to set)", self.grid.x + 36, ly)
    ly = ly + 24

    -- ...and the red rim, which is the one mark on this grid that reports a MISTAKE rather than a
    -- mechanic. Drawn as the rim itself rather than a colour swatch, so the legend and the cell are
    -- visibly the same thing.
    --
    -- It stands for two faults (unaffordable, and unmet requirement) and names neither, because the
    -- line has room for one of them at most and picking one would teach the player to read the rim as
    -- that one. What it promises instead is where the answer is, which is true of both.
    love.graphics.setColor(0.95, 0.35, 0.32, 0.90)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", self.grid.x, ly, 26, 16, 4, 4)
    love.graphics.setLineWidth(1)
    Theme.set(Theme.ink)
    love.graphics.print("Won't work here (hover to see why)", self.grid.x + 36, ly)
end

-- Loadout / Tactics segmented tabs, mirroring ui/panels/shop.lua's mode selector: filled + outlined
-- when active, flat when not.
function Party:drawModeSelector()
    love.graphics.setFont(self.smallFont)
    for _, m in ipairs(self.modes) do
        local r = self.segRects[m]
        local active = (self.mode == m)
        Theme.set(active and Theme.panel or Theme.panel2)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 5, 5)
        love.graphics.setLineWidth(active and 1.5 or 1)
        Theme.set(active and Theme.accentAmber or Theme.frame)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 5, 5)
        love.graphics.setLineWidth(1)
        Theme.set(active and Theme.accentAmber or Theme.muted)
        love.graphics.printf(MODE_LABEL[m], r.x, r.y + (r.h - self.smallFont:getHeight()) / 2, r.w, "center")
    end
    love.graphics.setColor(1, 1, 1)
end

function Party:drawPool()
    love.graphics.setFont(self.smallFont)
    Theme.set(Theme.muted)
    local label = self.debugAll and "Catalog (all items)" or "Stash"
    love.graphics.print(label .. " (" .. self.pool:count() .. ")", self.pool.x, self.poolHeaderY)
    self.pool:draw()
end

-- The development-only "All Items" pill at the right end of the tab band. Lit when the catalog is
-- installed. Drawn (and hit-tested) only when Debug.enabled, so a release build never shows it.
function Party:drawDebugToggle()
    local r = self.debugRect
    if not r then return end
    local on = self.debugAll
    Theme.set(on and Theme.panel or Theme.panel2)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 5, 5)
    Theme.set(on and Theme.accentWeapon or Theme.frame)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 5, 5)
    love.graphics.setFont(self.smallFont)
    Theme.set(on and Theme.accentWeapon or Theme.muted)
    love.graphics.printf("Debug: All Items " .. (on and "ON" or "OFF") .. "  [F1]",
        r.x, r.y + (r.h - self.smallFont:getHeight()) / 2, r.w, "center")
    love.graphics.setColor(1, 1, 1)
end

function Party:drawFooter()
    love.graphics.setFont(self.smallFont)
    if self.message then
        love.graphics.setColor(self.messageOk and 0.6 or 0.9, self.messageOk and 0.85 or 0.6,
            self.messageOk and 0.6 or 0.55)
        love.graphics.printf(self.message, self.boxX, self.boxY + BOX_H - 52, BOX_W, "center")
    end
    self:drawPromptBar()
end

-- Context-sensitive control hints, keyed on the focused region and whether an item is in hand -- so
-- the confirm button's meaning (Pick up / Place / Give / Stow) is always spelt out. The glyphs match
-- the device last used (pad buttons vs. keyboard keys); mouse falls back to the keyboard set.
-- "1/2", or "1/2/3" once the Stats tab is on. Derived from the tab list rather than spelled out, so a
-- hint that promises two number keys can't outlive the panel growing a third.
function Party:tabGlyph()
    local keys = {}
    for i in ipairs(self.modes) do keys[i] = tostring(i) end
    return table.concat(keys, "/")
end

function Party:drawPromptBar()
    local pad = InputMode.isGamepad()
    local confirmGlyph = pad and "A" or "Enter"
    local cancelGlyph = pad and "B" or "Esc"
    local regionGlyph = pad and "Y" or "Tab"
    local switchGlyph = pad and "LB/RB" or "Q/E"

    local segments = {}
    local function add(glyph, label, color) segments[#segments + 1] = { glyph = glyph, label = label, color = color } end

    local editor = self:columnEditor()
    if editor then
        if self.focus == "editor" then
            for _, seg in ipairs(editor:prompts()) do segments[#segments + 1] = seg end
        else
            add(confirmGlyph, "Select", PROMPT_GO)
        end
        add(cancelGlyph, "Close", PROMPT_NO)
        add(pad and "LT/RT" or self:tabGlyph(), "Tab")
        add(switchGlyph, "Switch")
        ButtonPrompt.draw(segments, self.boxX, self.boxY + BOX_H - 30, BOX_W, { align = "center" })
        return
    end

    local held = self.grid.picked or self.pool.picked
    if held then
        local label = (self.focus == "rail") and "Give"
            or (self.focus == "pool") and "Stow" or "Place/Swap"
        add(confirmGlyph, label, PROMPT_GO)
        add(cancelGlyph, "Cancel", PROMPT_NO)
        if self.focus == "rail" then
            add(regionGlyph, "Region")
            add(switchGlyph, "Switch")
        end
    else
        local label = (self.focus == "rail") and "Select"
            or (self.focus == "pool") and "Equip" or "Pick up"
        add(confirmGlyph, label, PROMPT_GO)
        add(cancelGlyph, "Close", PROMPT_NO)
        add(regionGlyph, "Region")
        add(switchGlyph, "Switch")
        add(pad and "LT/RT" or self:tabGlyph(), "Tab")
        -- The level forecast. A mouse can just point at the "Growing as X" clause, but a hover nobody
        -- knows about is a feature nobody has, and a pad has no hover at all -- so the toggle is spelt
        -- out here for every device.
        add(pad and "LS" or "G", "Growth")
        -- Set-default-action control, shown only when an ability cell is focused (it's the only place
        -- pinning does anything). Matches the star badge drawn on the grid cell.
        if self.focus == "grid" and self.grid:isActionCell(self.grid.cursor) then
            add(pad and "X" or "F", "Default")
        end
    end
    ButtonPrompt.draw(segments, self.boxX, self.boxY + BOX_H - 30, BOX_W, { align = "center" })
end

function Party:drawDrag()
    local drag = self.drag
    if not (drag and drag.active) then return end
    local item = self:dragItem()
    if not item then return end
    local x, y = drag.x - GHOST / 2, drag.y - GHOST / 2
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", x + 3, y + 3, GHOST, GHOST, 6, 6)
    local sprite = item.sprite
    if type(sprite) == "userdata" then
        love.graphics.setColor(1, 1, 1, 0.9)
        local iw, ih = sprite:getDimensions()
        local scale = math.min(GHOST / iw, GHOST / ih)
        love.graphics.draw(sprite, drag.x, drag.y, 0, scale, scale, iw / 2, ih / 2)
    else
        love.graphics.setColor(0.5, 0.5, 0.56, 0.9)
        love.graphics.rectangle("fill", x, y, GHOST, GHOST, 6, 6)
        love.graphics.setFont(self.headFont)
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.printf((item.name or "?"):sub(1, 1), x, y + GHOST / 2 - 12, GHOST, "center")
    end
    love.graphics.setColor(1, 1, 1)
end

-- Explain the default-action star when the pointer rests on the badge (mouse only), so its meaning
-- is a hover away and not just a legend line. Reads whether THIS cell is the current default so the
-- text tells the player what a click will do (pin it, or clear it). A small self-contained box near
-- the pointer, clamped on-screen; it replaces the item tooltip while the pointer is on the badge.
function Party:drawStarTooltip(cell)
    local pinned = self:currentChar() and self:currentChar().defaultActionSlot == cell
    local title = pinned and "Default action" or "Set default action"
    local body = "The action used for click-to-use on the battlefield and the reach band shown on this"
        .. " unit's turn. " .. (pinned and "Click the star to clear it."
            or "Click the star to pin it -- any ability can be the default.")

    local W, pad = 240, 10
    local _, lines = self.tinyFont:getWrap(body, W - pad * 2)
    local h = pad + self.smallFont:getHeight() + 4 + #lines * (self.tinyFont:getHeight() + 1) + pad
    local x = math.min(self.mx + 16, Scale.WIDTH - W - 8)
    local y = math.min(self.my + 16, Scale.HEIGHT - h - 8)

    Theme.set(Theme.panel, 0.97)
    love.graphics.rectangle("fill", x, y, W, h, 6, 6)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", x, y, W, h, 6, 6)
    love.graphics.setFont(self.smallFont)
    Theme.set(Theme.accentAmber)
    love.graphics.print(title, x + pad, y + pad)
    love.graphics.setFont(self.tinyFont)
    Theme.set(Theme.ink)
    love.graphics.printf(body, x + pad, y + pad + self.smallFont:getHeight() + 4, W - pad * 2, "left")
    love.graphics.setColor(1, 1, 1)
end

-- What the numbers under the TECHNIQUE caption actually are, shown when the caption is hovered. Returns
-- true when it drew.
--
-- The list is legible without this -- a house and a figure, ranked -- but nothing on the sheet says
-- where the figure comes FROM or what it is for, and technique is the one word here a player cannot
-- unpack from context: it is not gold, it is not experience, and it is earned and spent in two entirely
-- different places (a battle, and the Forge). Three short paragraphs, in the order a player meets them.
local TECHNIQUE_NOTE = {
    "Practice, banked per house. Every action a member takes teaches the house whose gear they used -- "
        .. "capped per battle, so no one long fight buys a discipline.",
    "It is what the Forge bills to raise an item a rung, and the bill is paid by whichever member holds "
        .. "the most of that house -- not by whoever happens to be carrying the item.",
    "What a member has been casting lately is also what its next level-up is made of. The line under "
        .. "their name names the house leading that; point at it to see what the level buys.",
}

function Party:drawTechniqueTooltip()
    local r = self.techniqueRect
    if not (r and self.mx and pointIn(r, self.mx, self.my)) then return false end
    return NoteTooltip.draw("Technique", TECHNIQUE_NOTE, self.mx, self.my, self.pool.x) ~= nil
end

-- Where the hovered stat's number comes from (ui/stat_tooltip.lua). Returns true when it drew, so the
-- caller can stop -- the stat block and the item grid never overlap, but the sheet is a legitimate place
-- to be pointing while an item sits under the pointer's LAST position, and two boxes at once is a mess.
--
-- Mouse only. The stat block is not a focus region -- Tab cycles grid / stash / rail and stops there --
-- so a pad has no cursor to put on a stat row, and inventing one to hang a tooltip off would be a
-- navigation change rather than a tooltip. The forecast, which is the reading a player steers by, is
-- reachable on every device (Party:growthPeeking); this is the reference lookup beside it.
function Party:drawStatTooltip()
    local key = self.mx and self:statAt(self.mx, self.my)
    if not key then return false end
    local char = self:currentChar()
    if not char then return false end

    local label
    for _, row in ipairs(STAT_ROWS) do
        if row.key == key then label = row.label break end
    end

    return StatTooltip.draw(Party.statSources(char, key), label or key,
        self.mx, self.my, self.pool.x) ~= nil
end

-- Item tooltip, sourced by the device in use so it never lingers out of place: with the mouse it
-- follows the pointer and shows only while a cell is hovered (so it clears the moment the pointer
-- leaves); with keyboard/gamepad it sits at the active region's cursor cell. Out of combat there is
-- no acting unit, so `actor` is nil: ItemTooltip shows the item's static stats.
--
-- The focused member goes down as the tooltip's `owner` instead, including for a STASH cell, where the
-- question the player is actually asking is "should this go to them" -- so the box priced against
-- whoever the sheet is showing is the one that can answer it before the item is handed over.
function Party:drawActiveTooltip()
    if self:columnEditor() then return end -- an editor labels its own fields; no item is on show
    if self.filterOpen then return end     -- the dropdown overlays the stash; no cell tooltip beneath it
    if InputMode.isMouse() and self:drawTechniqueTooltip() then return end
    if InputMode.isMouse() and self:drawStatTooltip() then return end
    if InputMode.isMouse() then
        -- The star badge under the pointer wins over the item tooltip (they'd otherwise stack in the
        -- cell's top-right corner), naming what a click there does.
        if self.grid.hoverStar then self:drawStarTooltip(self.grid.hoverStar) return end
        local item, maxRight
        if self.pool.hover then
            item, maxRight = self.pool:itemAt(self.pool.hover), Scale.WIDTH -- ItemTooltip flips left
        elseif self.grid.hover then
            local char = self:currentChar()
            item, maxRight = char and char.inventory[self.grid.hover], self.pool.x
        end
        if item then ItemTooltip.draw(item, self.mx, self.my, maxRight, nil, self:currentChar()) end
        return
    end

    -- Keyboard / gamepad: anchor at the focused region's cursor cell.
    local item, maxRight, ax, ay
    if self.focus == "pool" then
        item = self.pool:itemAt(self.pool.cursor)
        local cx, cy, cw = self.pool:cellRect(self.pool.cursor)
        if cx then maxRight, ax, ay = Scale.WIDTH, cx + cw, cy end
    elseif self.focus == "grid" then
        local char = self:currentChar()
        item = char and char.inventory[self.grid.cursor]
        local cx, cy, cw = self.grid:slotRect(self.grid.cursor)
        maxRight, ax, ay = self.pool.x, cx + cw, cy
    end
    if item and ax then ItemTooltip.draw(item, ax, ay, maxRight, nil, self:currentChar()) end
end

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------

-- Hand over anything you can pick: the close X, a party-member portrait on the rail, a loadout grid
-- cell, or a stash-pool cell. When the split-quantity popup is open it owns the pointer. Arrow over
-- the dead space between. See ui/cursor.lua.
function Party:cursorKind(x, y)
    if self.quantityPopup then return self.quantityPopup:cursorKind(x, y) end
    if self.closeButton:contains(x, y) then return "hand" end
    if self:railIndexAt(x, y) then return "hand" end
    if self:debugHit(x, y) then return "hand" end
    for _, m in pairs(self.segRects) do
        if pointIn(m, x, y) then return "hand" end
    end
    local editor = self:columnEditor()
    if editor then return editor:cursorKind(x, y) end
    if self.filterBtn and pointIn(self.filterBtn, x, y) then return "hand" end
    if self:filterIndexAt(x, y) then return "hand" end
    if self.grid:indexAt(x, y) or self.pool:contains(x, y) then return "hand" end
    return "arrow"
end

function Party:mousemoved(x, y)
    self.mx, self.my = x, y
    if self.quantityPopup then self.quantityPopup:mousemoved(x, y) return end
    self.closeButton:mousemoved(x, y)
    local editor = self:columnEditor()
    if editor then editor:mousemoved(x, y) return end
    self.grid:mousemoved(x, y)
    self.pool:mousemoved(x, y)
    local drag = self.drag
    if drag then
        drag.x, drag.y = x, y
        if math.abs(x - drag.startX) > DRAG_THRESHOLD or math.abs(y - drag.startY) > DRAG_THRESHOLD then
            drag.active = true
        end
    end
end

function Party:wheelmoved(_, dy)
    if dy == 0 then return end
    if self.quantityPopup then self.quantityPopup:wheelmoved(dy) return end
    local x, y = Scale.toGame(love.mouse.getPosition())
    local editor = self:columnEditor()
    if editor then
        if editor:contains(x, y) then editor:wheelmoved(dy)
        elseif self:railContains(x, y) then
            local maxOff = math.max(0, #self.chars - self.railVisible)
            self.railOffset = math.max(0, math.min(maxOff, self.railOffset - dy))
        end
        return
    end
    if self.pool:contains(x, y) then
        self.pool:wheelmoved(dy)
        self.pool:mousemoved(x, y)
    elseif self:railContains(x, y) then
        local maxOff = math.max(0, #self.chars - self.railVisible)
        self.railOffset = math.max(0, math.min(maxOff, self.railOffset - dy))
    end
end

function Party:mousepressed(x, y, button)
    if self.quantityPopup then self.quantityPopup:mousepressed(x, y, button) return end
    if button ~= 1 then return end
    if self.closeButton:mousepressed(x, y, button) then self:close() return end

    for _, m in ipairs(self.modes) do
        if pointIn(self.segRects[m], x, y) then self:setMode(m) return end
    end
    if self:debugHit(x, y) then self:toggleDebugAll() return end

    -- Clicking the growth clause pins the forecast open, so reading the whole stat column does not mean
    -- holding the pointer still on one line of text. Only with empty hands: mid-transfer, a click
    -- anywhere is about the item.
    if self.growthRect and not (self.grid.picked or self.pool.picked)
        and pointIn(self.growthRect, x, y) then
        self:toggleGrowthPeek()
        return
    end

    local empty = not (self.grid.picked or self.pool.picked)

    local ri = self:railIndexAt(x, y)
    if ri then
        self:setFocus("rail")
        self.railCursor = ri
        if self:columnEditor() then
            self:focusChar(ri)
            return
        end
        if self.grid.picked then
            self:giveGridItemToMember(self.grid.picked, ri)
        elseif self.pool.picked then
            self:givePoolItemToMember(self.pool.picked, ri)
        else
            self:focusChar(ri)
        end
        return
    end

    local editor = self:columnEditor()
    if editor then
        if editor:mousepressed(x, y) then
            self:setFocus("editor")
            return
        end
        if not pointIn({ x = self.boxX, y = self.boxY, w = BOX_W, h = BOX_H }, x, y) then self:close() end
        return
    end

    if self.filterBtn and pointIn(self.filterBtn, x, y) then
        self:toggleFilterPanel()
        return
    end
    if self.filterOpen then
        local fi = self:filterIndexAt(x, y)
        if fi then
            self:setFocus("filters")
            self.filterCursor = fi
            self:toggleFilter(fi)
            return
        end
        -- A click off the open dropdown just closes it, and is swallowed so it can't also equip or
        -- pick up whatever cell was sitting behind the overlay.
        if not pointIn(self.dropdownRect, x, y) then self:closeFilterPanel() end
        return
    end

    local cell = self.grid:indexAt(x, y)
    if cell then
        self:setFocus("grid")
        self.grid.cursor = cell
        -- A click on an ability cell's star badge pins/un-pins the default action instead of picking
        -- the item up. The grid can't see its own clicks here (the panel owns every grid mutation), so
        -- this mirrors InventoryGrid:mousepressed's star check -- without it the star is unreachable
        -- by mouse and every click just lifts the item.
        if empty and self.grid:isActionCell(cell) then
            local rx, ry, rw, rh = self.grid:starRect(cell)
            if x >= rx and x <= rx + rw and y >= ry and y <= ry + rh then
                self.grid:setDefaultAt(cell)
                return
            end
        end
        self:activateGrid(cell)
        if empty and self.grid.picked == cell then self:beginDrag("grid", cell, x, y) end
        return
    end

    local hit, idx = self.pool:mousepressed(x, y, button)
    if hit then
        if idx then
            self:setFocus("pool")
            if self.grid.picked then
                self:stowFromGrid(self.grid.picked)
            else
                -- Begin a potential drag. Released without dragging, this reads as a click and
                -- auto-equips (mousereleased); dragged, it lets the player aim a slot/member/quantity.
                self:beginDrag("pool", idx, x, y)
            end
        end
        return
    end

    if not pointIn({ x = self.boxX, y = self.boxY, w = BOX_W, h = BOX_H }, x, y) then
        self:close()
    end
end

function Party:mousereleased(x, y, button)
    if self.quantityPopup then self.quantityPopup:mousereleased(x, y, button) return end
    if button ~= 1 then return end
    -- An editor column owns the whole box while it is up (see mousepressed), including the release
    -- that ends a row drag. The panel's own item drag is never armed in that mode, so there is
    -- nothing here for dropDrag to finish.
    local editor = self:columnEditor()
    if editor then
        if editor.mousereleased then editor:mousereleased(x, y, button) end
        return
    end
    local drag = self.drag
    if drag and drag.from == "pool" and not drag.active then
        -- A click on a stash cell (pressed and released in place): equip it to the focused member.
        self.drag = nil
        self:equipStashItem(drag.index)
        return
    end
    self:dropDrag(x, y)
end

function Party:keypressed(key)
    if self.quantityPopup then self.quantityPopup:keypressed(key) return end
    -- Number keys jump straight to a tab, in the order the strip shows them.
    for i, m in ipairs(self.modes) do
        if key == tostring(i) then self:setMode(m) return end
    end

    local editor = self:columnEditor()
    if key == "escape" then
        self.drag = nil
        if self.filterOpen then self:closeFilterPanel() return end -- shut the dropdown before the panel
        local caught = (editor and editor:cancel())
            or self.grid:cancelPickup() or self.pool:cancelPickup()
        if not caught then self:close() end
    elseif key == "f1" then
        self:toggleDebugAll()
    elseif key == "g" then
        self:toggleGrowthPeek()
    elseif key == "tab" then
        self:cycleFocus(1)
    elseif key == "q" then
        self:switchChar(-1)
    elseif key == "e" then
        self:switchChar(1)
    -- On a column-editor tab, A/D/W/S are not navigation: they are letters, and the arrows are the
    -- canonical path there because left/right CHANGES a value rather than moving a cursor -- a stray
    -- "a" nudging a priority band (or a stat) would be baffling.
    elseif key == "left" or (key == "a" and not editor) then self:navigate(-1, 0)
    elseif key == "right" or (key == "d" and not editor) then self:navigate(1, 0)
    elseif key == "up" or (key == "w" and not editor) then self:navigate(0, -1)
    elseif key == "down" or (key == "s" and not editor) then self:navigate(0, 1)
    elseif key == "f" then
        if editor and self.focus == "editor" then
            if editor.toggleEnabled then editor:toggleEnabled(editor.cursor) end
        elseif self.focus == "grid" then
            self.grid:setDefaultAt(self.grid.cursor)
        end
    elseif key == "delete" or key == "backspace" then
        if editor and self.focus == "editor" and editor.removeRule then
            editor:removeRule(editor.cursor)
        end
    elseif key == "return" or key == "kpenter" or key == "space" then self:confirm()
    end
end

function Party:gamepadpressed(joystick, button)
    if self.quantityPopup then self.quantityPopup:gamepadpressed(joystick, button) return end
    -- Triggers switch tab, shoulders switch character. The shoulders were already the character
    -- switch and moving them would break a habit for the sake of a new feature.
    if button == "triggerleft" then self:cycleMode(-1) return end
    if button == "triggerright" then self:cycleMode(1) return end

    local editor = self:columnEditor()
    if button == "b" then
        self.drag = nil
        if self.filterOpen then self:closeFilterPanel() return end -- shut the dropdown before the panel
        local caught = (editor and editor:cancel())
            or self.grid:cancelPickup() or self.pool:cancelPickup()
        if not caught then self:close() end
    elseif button == "y" then
        self:cycleFocus(1)
    elseif button == "leftshoulder" then
        self:switchChar(-1)
    elseif button == "rightshoulder" then
        self:switchChar(1)
    elseif button == "dpleft" then self:navigate(-1, 0)
    elseif button == "dpright" then self:navigate(1, 0)
    elseif button == "dpup" then self:navigate(0, -1)
    elseif button == "dpdown" then self:navigate(0, 1)
    elseif button == "x" then
        if editor and self.focus == "editor" then
            if editor.toggleEnabled then editor:toggleEnabled(editor.cursor) end
        elseif self.focus == "grid" then
            self.grid:setDefaultAt(self.grid.cursor)
        end
    elseif button == "leftstick" then
        -- The keyboard's G. X and Back are both spoken for above, and the stick click is the only free
        -- button left that is not already load-bearing somewhere in this panel.
        self:toggleGrowthPeek()
    elseif button == "back" then
        if editor and self.focus == "editor" and editor.removeRule then
            editor:removeRule(editor.cursor)
        end
    elseif button == "a" then self:confirm()
    end
end

return Party
