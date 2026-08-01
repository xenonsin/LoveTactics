-- Draft mode: the Super-Auto-Pets-style roguelike-draft screen. Between rounds you spend a budget in
-- the store (drafting characters and gear scaled to the round), arrange the four you field in a
-- MARCHING FORMATION with reserves on a bench, combine duplicates to strengthen them, then Fight -- a
-- piloted tactical battle on the moving-node control board against a round-scaled bot. Three losses
-- ends the run; ten wins takes it.
--
-- Like Super Auto Pets, the mouse drives this by DRAG, not click: drag a store card onto the formation
-- (or bench) to recruit, drag a unit onto a same-kind unit to combine, drag a store card straight onto a
-- unit of its OWN kind to buy and combine in one motion, drag between cells to rearrange, drag gear onto
-- a unit to equip, and drag a unit or item onto Sell to cash it out. A unit the thing in hand would
-- combine with wears a green ring while the drag is live, so the combine never has to be guessed at.
-- Keyboard and gamepad can't drag, so they keep a pick-up / drop equivalent (the project's three-input
-- standard): a cursor walks the interactive things, confirm picks up or drops -- and confirming a store
-- card while HOLDING a unit of its kind is that device's buy-and-combine.
--
-- GEAR IS THE DRAFT. A bought unit arrives as a chassis -- its signature weapon and verb, and eight
-- empty cells (models/draft_chassis.lua) -- so the store's gear row, not its unit row, is where a build
-- comes from. The screen is built around reading that: a unit card carries a keyword line and a strip
-- of what it holds, and hovering one opens an ANCHORED sheet plus, fanned out beside it, the full shared
-- ItemTooltip for EVERY piece it carries at once (drawKitCluster) over one merged glossary. Nothing a
-- player fields should be something they never read, and reading a build should cost one hover.
--
-- The RULES live in the model layer (models/draft_run, draft_shop, draft_match, draft_chassis); this
-- state is the screen and the input over them. The FORMATION is the up-to-four fielded units seated by cell (front
-- row faces the enemy; models/arena.lua seats the party into exactly this shape via
-- DraftRun.formationSlots), the BENCH is the reserves behind them.
--
-- Flow: enter -> shop/arrange -> Fight -> states.battle -> (onWin/onLoss) -> back here for the next
-- round, or the terminal card when the run is decided. The run persists to disk after every battle, so
-- quitting mid-run and reopening Draft finds it waiting -- and ASKS: continue that run, or abandon it
-- and draft a fresh one (draft.card, below). A saved run is never silently resumed nor silently thrown
-- away, because either one is a whole evening of drafting decided for the player.

local State = require("states")
local Scale = require("scale")
local Theme = require("ui.theme")
local InputMode = require("input_mode")
local CloseButton = require("ui.close_button")
local DraftRun = require("models.draft_run")
local DraftShop = require("models.draft_shop")
local DraftMatch = require("models.draft_match")
local DraftChassis = require("models.draft_chassis")
local Character = require("models.character")
local Item = require("models.item")
local Sprite = require("models.sprite")
local ItemTooltip = require("ui.item_tooltip")
local GlossaryPanel = require("ui.glossary_panel")
local Glossary = require("models.glossary")
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

-- The modal cards, defined with the rest of the card code further down but used by `enter`.
local showTerminal, promptResume

-- ---------------------------------------------------------------------------
-- Entry / run lifecycle
-- ---------------------------------------------------------------------------

function draft.enter(self, opts)
    opts = opts or {}
    -- Clear any screen effects a battle left standing -- a lost fight fades the world to grey, and
    -- returning to the shop must open on full colour again rather than that defeat grey (ui/screen_fx.lua).
    ScreenFx.reset()
    draft.card = nil
    -- Where leaving goes: whatever opened the mode, which in the shipped game is the city's Draft Yard
    -- (data/buildings/draft_yard.lua). Only a fresh entry sets this -- a `resume` is the return from a
    -- battle, which carries no opts of its own and must not forget the city it was entered from.
    if not opts.resume then draft.returnTo = opts.returnTo end
    local askResume = false
    if not opts.resume then
        -- Opened fresh from the menu: load a saved run that is still in progress (the player is asked
        -- below whether to keep it), else start a new one.
        local saved = DraftRun.read()
        askResume = saved ~= nil and DraftRun.outcome(saved) == nil
        draft.run = askResume and saved or DraftRun.new()
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
    -- The question this screen opens on, if any: the run is decided, or a saved one is waiting.
    if draft.terminal then showTerminal()
    elseif askResume then promptResume() end
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

-- What a unit merge did to the gear, as a tail for the toast: the pieces it upgraded (named, so the
-- " +n" instantiate hangs on the name does the reporting) and a count of what went to the stash. A
-- merge now moves gear as well as a level, and the player has to be told which -- silently upgrading a
-- weapon reads as nothing having happened.
local function mergeSpoils(result)
    local parts = {}
    for _, item in ipairs(result and result.upgraded or {}) do
        parts[#parts + 1] = item.name or item.id
    end
    if (result and result.stashed or 0) > 0 then
        parts[#parts + 1] = result.stashed .. " to stash"
    end
    return #parts > 0 and ("  --  " .. table.concat(parts, ", ")) or ""
end

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

-- Drop a store unit card onto a unit already drafted: when the two are the same kind, buy AND combine in
-- one motion (the shortcut for buy-it-then-drag-the-duplicate, and the only way to upgrade once the
-- formation and bench are both full). Anything else is a plain recruit onto `dest`, so dropping a
-- Fighter card on a Knight still just drafts the Fighter where it was aimed.
local function recruitUnitInto(entry, target, dest)
    if not DraftRun.canMergeIdInto(entry.id, target) then return recruitUnit(entry, dest) end
    local result, why = DraftShop.buyUnitInto(draft.run, entry, target)
    if not result then say("Can't combine: " .. tostring(why)) return end
    say("Drafted & combined -- " .. (result.unit.name or result.unit.id) .. " is now level " .. result.toLevel
        .. mergeSpoils(result))
end

-- Recruit the store gear in `entry` (it lands in the stash), and put it on `unit` when one is named
-- (a drag that ended on a unit): combining with a piece that unit already carries, else taking a free
-- cell. Buy-and-combine for gear, the twin of DraftShop.buyUnitInto for units.
local function recruitGear(entry, unit)
    local item, why = DraftShop.buyGear(draft.run, entry)
    if not item then say("Can't buy: " .. tostring(why)) return end
    if not unit then say("Bought " .. (item.name or item.id)) return end

    local merged = DraftRun.mergeItemInto(unit, item)
    if merged then
        DraftShop.take(draft.run.stash, item)
        say("Bought & combined -- " .. (merged.name or merged.id))
    elseif Character.firstEmptySlot(unit) then
        DraftShop.take(draft.run.stash, item)
        Character.addItem(unit, item)
        say("Bought & equipped " .. (item.name or item.id))
    else
        say("Bought " .. (item.name or item.id))
    end
end

-- Put a stash `item` on `unit`: combine with a matching piece already on its grid (in place, one level
-- higher -- the same cascade DraftRun.mergeUnit runs automatically, so the manual drag and the
-- automatic one never teach two different rules), else take the next free cell.
local function equipGear(item, unit)
    if not (item and unit) then return end
    local merged = DraftRun.mergeItemInto(unit, item)
    if merged then
        DraftShop.take(draft.run.stash, item)
        say("Combined into " .. (merged.name or merged.id))
        draft.selectedGear = nil
    elseif Character.firstEmptySlot(unit) then
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
        say(res and ("Combined -- now level " .. res.toLevel .. mergeSpoils(res)) or "Can't combine those.")
    elseif not DraftRun.placeInCell(draft.run, mover, cell) then
        say("Formation is full (" .. DraftRun.PARTY_MAX .. ").")
    end
end

-- Drop `mover` onto another unit `target`: combine same kinds, else demote the mover to the bench.
local function dropUnitOnUnit(mover, target)
    if mover == target then return end
    if DraftRun.canMergeUnits(mover, target) then
        local res = DraftRun.mergeUnit(draft.run, mover, target)
        say(res and ("Combined -- now level " .. res.toLevel .. mergeSpoils(res)) or "Can't combine those.")
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

-- Merge two stash copies of the same item into one a level above the better of them.
local function mergeGear(a, b)
    local merged = DraftRun.mergeItems(a, b)
    if not merged then say("Those don't combine -- it takes two copies of the same item.") return false end
    DraftShop.take(draft.run.stash, a)
    DraftShop.take(draft.run.stash, b)
    draft.run.stash[#draft.run.stash + 1] = merged
    say("Combined into " .. (merged.name or merged.id))
    draft.selectedGear = nil
    return true
end

-- Drop a store gear card onto a stash card: buy it and combine the two, the stash-side twin of dragging
-- the card onto a unit that already carries the piece. A pair that does not combine is just a purchase --
-- both halves are in the stash either way, so nothing is lost by the near-miss.
local function buyGearOnto(entry, stashItem)
    local item, why = DraftShop.buyGear(draft.run, entry)
    if not item then say("Can't buy: " .. tostring(why)) return end
    if DraftRun.canMergeItems(stashItem, item) then
        mergeGear(stashItem, item)
    else
        say("Bought " .. (item.name or item.id))
    end
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
    -- Note what every consumable stack marches out with, so the round rollover can pour it back
    -- (DraftRun.stockConsumables / refillConsumables): a draft potion is part of a build, not a
    -- one-round rental. Here rather than in the model's battle-opts factory because THIS is the
    -- gate -- the last instant before the fight starts spending them.
    DraftRun.stockConsumables(draft.run)
    local match = DraftMatch.find(draft.run, nil)
    State.switch(require("states.battle"), DraftMatch.battleOpts(draft.run, match, {
        chessClock = draft.CHESS_SECONDS,
        onWin = function() draft.afterBattle("win") end,
        onLoss = function() draft.afterBattle("loss") end,
    }))
end

-- Leaving the mode: back to whatever opened it. The label says which, so "Back" never lies about where
-- it drops you. The title-screen fallback is for a caller that names no destination (a debug entry);
-- the city always names one.
local function leave() State.switch(draft.returnTo or require("states.menu")) end
local function leaveLabel() return draft.returnTo and "Back to City" or "Back to Menu" end

-- ---------------------------------------------------------------------------
-- Modal cards (resume the saved run / abandon it / the terminal)
-- ---------------------------------------------------------------------------
--
-- Three moments stop the shop and ask one question: the saved-run choice on entry, the abandon confirm,
-- and the terminal when the run is decided. All three are the same object -- a title, a line of body and
-- a row of buttons -- so they share one drawer (draft.drawCard) and one branch per input device instead
-- of three bespoke ones. A card is MODAL: every input handler returns at `draft.card` before it reaches
-- the shop's targets, so nothing behind one can be clicked, cursored or dragged -- but the shop is still
-- laid out and drawn underneath (except behind the terminal), because the run being asked about should
-- stay readable while the player decides.

local function showCard(card)
    draft.card = card
    draft.cursor = 1
end

local function closeCard()
    draft.card = nil
    draft.cursor = 1
end

-- Delete the saved run and open a fresh one in place. Deliberately not a state switch: re-entering
-- would read the file we just cleared and there would be nothing left to ask about, but it would also
-- throw away the fresh run this call just made.
local function startFreshRun()
    DraftRun.clear()
    draft.run = DraftRun.new()
    DraftShop.roll(draft.run)
    draft.terminal = nil
    draft.held, draft.selectedGear, draft.drag = nil, nil, nil
    closeCard()
    say("New run -- round 1.")
end

-- Abandoning is the only irreversible button on this screen, so it asks first, and the safe answer is
-- the one the cursor opens on.
local function confirmAbandon()
    local r = draft.run
    showCard({
        title = "Abandon Run?",
        body = ("Round %d -- %d of %d wins, %d of %d lives lost.\n\nThis run is deleted for good, and a new one starts at round 1.")
            :format(r.round or 1, r.wins or 0, DraftRun.WIN_TARGET, r.losses or 0, DraftRun.LIVES),
        buttons = {
            { label = "Keep Playing", activate = closeCard },
            { label = "Abandon Run", activate = startFreshRun },
        },
        cancel = closeCard,
    })
end

-- Asked once, on opening Draft with a run saved from a previous sitting.
function promptResume()
    local r = draft.run
    showCard({
        title = "Run in Progress",
        body = ("Round %d -- %d of %d wins, %d of %d lives lost.\n\nContinue this run, or abandon it and draft a new one?")
            :format(r.round or 1, r.wins or 0, DraftRun.WIN_TARGET, r.losses or 0, DraftRun.LIVES),
        buttons = {
            { label = "Continue", activate = closeCard },
            { label = "New Run", activate = confirmAbandon },
            { label = leaveLabel(), activate = leave },
        },
        cancel = leave,
    })
end

-- The run is decided: ten wins taken, or three lives spent.
function showTerminal()
    local won = draft.terminal == "won"
    local round = draft.run.round or 1
    showCard({
        title = won and "Run Won!" or "Eliminated",
        body = won and ("Ten wins. You took the draft in " .. round .. " rounds.")
            or ("Three losses at round " .. round .. ". The run is over."),
        buttons = {
            { label = "New Run", activate = startFreshRun },
            { label = leaveLabel(), activate = leave },
        },
        cancel = leave,
        blackout = true, -- nothing behind this card is playable any more; hide it rather than tease it
    })
end

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

    -- Where a hovered STORE unit's sheet opens: the empty band right of the card rows, before the
    -- Reroll button. Anchoring it to the card itself would park it on top of the neighbouring cards --
    -- exactly the two units the player is trying to compare it against.
    self.storeCardAnchor = { x = math.max(sx, gx) + 8, y = sy - 8 }

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
    -- Quitting a run you have soured on without walking out to the menu first. Confirms before it bites.
    target(targets, MARGIN + 350, by, 170, 44, { kind = "button", label = "Abandon Run", activate = confirmAbandon })
    target(targets, W - MARGIN - 200, by, 200, 44, { kind = "fight", label = "Fight", activate = fight })
    target(targets, W - MARGIN - 200 - 170, by, 150, 44, { kind = "button", label = "Back", activate = leave })

    self.targets = targets
    -- The shop is still laid out under a modal card (it stays visible behind one, so it must keep its
    -- geometry), but the card owns the cursor -- leave it indexing the card's buttons, not this list.
    -- Input never reaches these targets while a card is up; every handler returns at draft.card first.
    if self.card then return end
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
    if InputMode.isMouse() and draft.mx and not draft.card then
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
-- The ring a unit wears when the thing in hand would COMBINE with it. Support green, borrowed from the
-- battle overlay vocabulary (ui/colors.lua) where the same green already means "this makes it better".
local MERGE_COLOR = Theme.Colors.SUPPORT

-- Stand-in instances for what the STORE is offering, memoized so a hovered card is not rebuilt every
-- frame. Both are read by the card drawing as well as the tooltips, so they live above both.
local previewGear = {}
local function gearInstance(entry)
    local key = entry.id .. "@" .. (entry.level or 0)
    if previewGear[key] == nil then previewGear[key] = Item.instantiate(entry.id, nil, entry.level) end
    return previewGear[key]
end

-- The unit a store card is offering, as the player would actually receive it: a CHASSIS, stripped to its
-- signature weapon and verb (models/draft_chassis.lua). Previewing the full blueprint body here would
-- advertise seven items that never arrive.
local previewUnit = {}
local function unitInstance(entry)
    if previewUnit[entry.id] == nil then previewUnit[entry.id] = DraftChassis.instantiate(entry.id) end
    return previewUnit[entry.id]
end

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

-- A card frame: filled inset, border support-green when the drop would COMBINE with it (outranking
-- everything, exactly as it does on a unit token), amber when focused, blue when selected.
local function cardFrame(t, focused, selected, merge)
    Theme.set(selected and Theme.slot or Theme.panel2)
    love.graphics.rectangle("fill", t.x, t.y, t.w, t.h, Theme.R, Theme.R)
    love.graphics.setLineWidth((merge or focused) and 2 or 1)
    if merge then Theme.set(MERGE_COLOR)
    elseif selected then Theme.set(Theme.cursor)
    elseif focused then Theme.set(Theme.accentAmber)
    else Theme.set(Theme.frame) end
    love.graphics.rectangle("line", t.x, t.y, t.w, t.h, Theme.R, Theme.R)
    love.graphics.setLineWidth(1)
end

-- The kit along a unit token's foot, as the ITEMS THEMSELVES rather than a count. This used to be nine
-- anonymous amber squares, which told you how much a unit carried and nothing about what -- and once a
-- drafted body is a chassis the player gears up piece by piece, WHICH pieces is the only interesting
-- question. Small enough to read as a texture at a glance, faithful enough to pick a unit out by its kit.
-- Coloured by item TYPE, so the strip says what a unit is carrying (three weapons and an armor reads
-- differently from four abilities) in the width a 72px token can spare. The item icons themselves are
-- too small to tell apart here -- they live in the hover card, which has room (drawUnitTooltip).
local function drawKitStrip(char, x, y, width)
    local items = Character.eachItem(char)
    if #items == 0 then return end
    local n = math.min(#items, Character.MAX_INVENTORY)
    local pip = math.max(3, math.min(7, math.floor(width / n) - 2))
    for i = 1, n do
        local c = TYPE_COLOR[items[i].type] or UNIT_COLOR
        love.graphics.setColor(c[1], c[2], c[3], 0.95)
        love.graphics.rectangle("fill", x + (i - 1) * (pip + 2), y, pip, pip, 1, 1)
    end
    love.graphics.setColor(1, 1, 1)
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
    else
        -- What this body DOES, in two or three words: its weapon family and what its kit grants. The
        -- unit row is meant to be comparable at a glance, without opening a single tooltip.
        local words = DraftChassis.keywords(unitInstance(entry))
        if #words > 0 then
            Theme.set(Theme.muted)
            love.graphics.print(Theme.ellipsize(table.concat(words, " · "), smallFont, tw), tx, t.y + 32)
        end
        drawKitStrip(unitInstance(entry), tx, t.y + 50, tw)
    end
    Theme.set(afford and Theme.accentAmber or { 0.6, 0.4, 0.4 })
    love.graphics.print(entry.price .. "g", t.x + 8, t.y + t.h - 22)
    if entry.frozen then
        Theme.set(Theme.cursor)
        love.graphics.print("FROZEN", t.x + t.w - 8 - smallFont:getWidth("FROZEN"), t.y + t.h - 22)
    end
end

-- What is in hand right now, as { kind, ref }: a live drag if there is one, else the keyboard/pad
-- pick-up (a held unit or a selected stash item). One reading, so the ring, the drop and the confirm
-- key can never disagree about what the player is carrying.
local function inHand()
    local d = draft.drag
    if d and d.active then return d.kind, d.ref end
    if draft.held then return "unit", draft.held end
    if draft.selectedGear then return "gear", draft.selectedGear end
    return nil
end

-- Would dropping what is currently in hand onto `char` COMBINE with something? True for a store card
-- mid-drag (dropping it there buys and merges in one motion), a dragged owned unit, a keyboard/pad
-- pick-up, and -- since a merge now runs at both levels -- gear that would upgrade a piece the unit is
-- already carrying. Drives the green ring below, so the shortcut announces itself while the card is
-- still moving instead of being a thing you have to already know.
local function mergeCandidate(char)
    if not char then return false end
    local kind, ref = inHand()
    if kind == "shopUnit" then return DraftRun.canMergeIdInto(ref.id, char) end
    if kind == "unit" then return DraftRun.canMergeUnits(ref, char) end
    -- Store entries carry an id and a level, which is all mergeSlotFor reads.
    if kind == "gear" or kind == "shopGear" then return DraftRun.mergeSlotFor(char, ref) ~= nil end
    return false
end

-- The same question for a STASH card: would what is in hand combine with this loose piece? Gear got the
-- ring late -- the screen is drag-driven by design, but item merging was click-only and unannounced.
local function gearMergeCandidate(item)
    if not item then return false end
    local kind, ref = inHand()
    if kind ~= "gear" and kind ~= "shopGear" then return false end
    return ref ~= item and DraftRun.canMergeItems(item, ref)
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
        drawKitStrip(char, cx + 5, cy + size - 22, size - 10)
    elseif opts.held then
        love.graphics.setFont(smallFont)
        Theme.set(Theme.muted)
        love.graphics.printf("moving...", cx, cy + size / 2 - 8, size, "center")
    end

    -- A unit this drop would COMBINE with outranks every other frame: it is the one border that says the
    -- drop does something other than move a body around. Support green (ui/colors.lua), so it reads as a
    -- gain and never collides with the amber focus or the blue cursor.
    love.graphics.setLineWidth((opts.merge or opts.focused) and 2 or 1)
    if opts.merge then Theme.set(MERGE_COLOR)
    elseif opts.selected then Theme.set(Theme.cursor)
    elseif opts.focused then Theme.set(Theme.accentAmber)
    else Theme.set(opts.frame or Theme.frame) end
    love.graphics.rectangle("line", cx, cy, size, size, 6, 6)
    love.graphics.setLineWidth(1)
end

local function drawGearRow(t, item, focused, selected, merge)
    cardFrame(t, focused, selected, merge)
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

-- The kit grid inside a unit's hover card.
local KIT_COLS, KIT_SLOT, KIT_GAP = 5, 34, 4

-- Draw the unit sheet near (mx, my) -- offset off that point like an item tooltip, or pinned exactly on
-- it when `exact` (the card has been frozen where it stands). Appends its item slot rects to `slots` and
-- returns the card's own rect, so the caller can hit-test both.
local function drawUnitTooltip(char, mx, my, slots, exact)
    slots = slots or {}
    local title, body, small = Theme.display(15), Theme.body(12), Theme.body(11)
    local pad, w = 9, 220
    local titleH, bodyH = title:getHeight(), body:getHeight()

    local rows = {}
    for _, r in ipairs(UNIT_STATS) do
        local text = statText(char, r)
        if text then rows[#rows + 1] = { label = r.label, value = text } end
    end
    local gear = Character.eachItem(char)
    local kitRows = math.ceil(#gear / KIT_COLS)

    local statRows = math.ceil(#rows / 2)
    local h = pad + titleH + 3 + bodyH + 6
        + statRows * (bodyH + 2)
        + (#gear > 0 and (8 + bodyH + 4 + kitRows * (KIT_SLOT + KIT_GAP)) or 0)
        + pad

    local maxX = Scale.WIDTH - w - 4
    local bx, by
    if exact then
        bx, by = mx, my
    else
        bx = mx + 14
        if bx > maxX then bx = mx - w - 14 end
        by = my + 16
    end
    bx = math.max(4, math.min(bx, maxX))
    by = math.max(4, math.min(by, Scale.HEIGHT - h - 4))

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

    -- The kit as ICONS, not a list of names. A name tells you nothing about a weapon family's mechanic,
    -- its range, what it costs or what trait it grants -- and every one of those decides whether the unit
    -- is worth 3g. Which is why the icons are only the INDEX: the full card for each piece opens beside
    -- this one (drawKitCluster), and the slots are recorded so the pointer resting on an icon can ring
    -- its card in the fan -- and so a kit too big for the screen can still be read a piece at a time,
    -- which is why the card FREEZES once the pointer steps off the unit onto it rather than trailing the
    -- cursor forever: you have to be able to land on it.
    if #gear > 0 then
        ty = ty + 8
        Theme.set(Theme.accentAmber)
        love.graphics.print("Carries", bx + pad, ty)
        ty = ty + bodyH + 4
        for i, item in ipairs(gear) do
            local col, row = (i - 1) % KIT_COLS, math.floor((i - 1) / KIT_COLS)
            local sx = bx + pad + col * (KIT_SLOT + KIT_GAP)
            local sy = ty + row * (KIT_SLOT + KIT_GAP)
            drawIcon(sx, sy, KIT_SLOT, item.sprite, item.name or item.id, TYPE_COLOR[item.type] or UNIT_COLOR)
            slots[#slots + 1] = { x = sx, y = sy, w = KIT_SLOT, h = KIT_SLOT, item = item }
        end
        ty = ty + kitRows * (KIT_SLOT + KIT_GAP)
    end
    love.graphics.setColor(1, 1, 1)
    return { x = bx, y = by, w = w, h = h }
end

-- ---------------------------------------------------------------------------
-- The kit cluster: every carried piece's tooltip, open at once beside the sheet
-- ---------------------------------------------------------------------------
--
-- A draft unit IS its gear -- the chassis is one weapon and a verb (models/draft_chassis.lua), and
-- everything after that is what the shelf sold you -- so "what does this unit do" is five item cards, not
-- one. Making the player travel the pointer onto each icon in turn to read them, one at a time, is the
-- slowest possible way to ask it, and the round clock is running. So the sheet opens the lot: one full
-- tooltip per piece, fanned into columns beside the card, with a single merged glossary at the end.

local CLUSTER_GAP = 8 -- between the unit card and the first tooltip column, and between columns

-- Every column starts at the same fixed top rather than at the card's own y. An item tooltip is a third
-- of the screen tall, and the card opens under a pointer that is usually somewhere in the middle of it --
-- so hanging the fan off the card's top edge would throw away everything above the pointer and fit ONE
-- box per column. Squared off at the top, a column holds two, and the fan reads as one block besides.
local CLUSTER_TOP = 6

-- Measured tooltips, memoized on the item instance. Measuring runs an ability dry run and wraps every
-- line (ui/item_tooltip.lua), which is fine once per hover and ruinous nine times per frame -- and the
-- instances behind a card are themselves memoized, so the keys are stable while the pointer rests.
-- Weak-keyed: a stand-in for a store offer the player never bought should not outlive the offer.
local kitLayouts = setmetatable({}, { __mode = "k" })
local function kitLayout(item)
    local l = kitLayouts[item]
    if l == nil then
        l = ItemTooltip.measure(item) or false
        kitLayouts[item] = l
    end
    return l or nil
end

-- Every status the whole kit can inflict and every keyword it declares, each defined once. One merged
-- aside rather than one per tooltip: the pieces of a kit overlap heavily (two bleed weapons, one Bleed),
-- and nine asides would want more screen than the tooltips they explain.
local function kitGlossary(gear)
    local entries, seen = {}, {}
    for _, item in ipairs(gear) do
        local l = kitLayout(item)
        for _, e in ipairs(Glossary.forItem(item, nil, l and l.out)) do
            if not seen[e.id] then seen[e.id] = true; entries[#entries + 1] = e end
        end
    end
    return entries
end

-- Fan the kit out beside `card` (the unit sheet's rect). Columns march AWAY from the card on whichever
-- side has more room, and each piece drops into the FIRST column with room left under what is already
-- there -- not simply the newest one, since a card is anything from a two-line potion to a full weapon
-- with a range diagram, and strict top-down order would leave a third of a column standing empty under
-- every short one. The merged glossary takes the column past the last, its width reserved up front so
-- the tooltips never have to shuffle for it.
--
-- Returns the set of items it managed to show. A kit bigger than the screen leaves the remainder to the
-- hover-the-icon path rather than dropping it silently -- the sheet's own icon strip is still the index.
local function drawKitCluster(gear, card, hoveredItem)
    local shown = {}
    if #gear == 0 then return shown end

    local W, GW = ItemTooltip.WIDTH, GlossaryPanel.WIDTH
    local entries = kitGlossary(gear)
    local reserve = (#entries > 0) and (GW + CLUSTER_GAP) or 0

    -- Right of the card unless the left side is roomier: the card sits under the pointer, which is as
    -- often on the right of the screen (bench, stash) as on the left (store).
    local roomRight = Scale.WIDTH - 4 - (card.x + card.w) - CLUSTER_GAP
    local roomLeft = (card.x - CLUSTER_GAP) - 4
    local dir = (roomRight >= W or roomRight >= roomLeft) and 1 or -1
    if math.max(roomRight, roomLeft) < W then return shown end

    -- Where column `i` (1-based) starts, growing outward from the card's near edge, and whether opening
    -- it still leaves the glossary the slot beyond it.
    local function colX(i)
        local step = (i - 1) * (W + CLUSTER_GAP)
        if dir == 1 then return card.x + card.w + CLUSTER_GAP + step end
        return card.x - CLUSTER_GAP - W - step
    end
    local function colFits(i)
        local x = colX(i)
        if dir == 1 then return x + W + reserve <= Scale.WIDTH - 4 end
        return x - reserve >= 4
    end

    local bottom = Scale.HEIGHT - 4
    local cols = {} -- the next free y in each open column
    for _, item in ipairs(gear) do
        local l = kitLayout(item)
        if l then
            local at
            for i = 1, #cols do
                if cols[i] + l.h <= bottom then at = i; break end
            end
            if not at and colFits(#cols + 1) then
                at = #cols + 1
                cols[at] = CLUSTER_TOP
            end
            if at then
                -- The piece the pointer is resting on wears the cursor ring, so a hovered icon and its
                -- card are visibly the same thing in a wall of five near-identical boxes.
                local accent = (item == hoveredItem) and Theme.accentAmber or nil
                ItemTooltip.paint(l, colX(at), cols[at], { accent = accent })
                shown[item] = true
                cols[at] = cols[at] + l.h + CLUSTER_GAP
            end
        end
    end

    -- The definitions land in the column past the last tooltip -- unless the kit ate the screen, in
    -- which case they are the thing to drop: a box explaining terms is worth less than the boxes that
    -- used them, and the item hover still carries its own aside for whatever the cluster left out.
    if #entries > 0 and #cols > 0 then
        local gx = (dir == 1) and colX(#cols + 1) or (colX(#cols) - CLUSTER_GAP - GW)
        if gx >= 4 and gx + GW <= Scale.WIDTH - 4 then GlossaryPanel.drawAt(entries, gx, CLUSTER_TOP) end
    end
    return shown
end

-- The target the pointer (mouse) or the cursor (keyboard/gamepad) is on -- what a tooltip describes.
local function hoveredTarget()
    if InputMode.isMouse() then
        for _, t in ipairs(draft.targets) do if t.hovered then return t end end
        return nil
    end
    return draft.targets[draft.cursor]
end

-- Is (mx, my) inside `rect`, grown by `pad` on every side?
local function inside(rect, mx, my, pad)
    pad = pad or 0
    return rect and mx and my
        and mx >= rect.x - pad and mx <= rect.x + rect.w + pad
        and my >= rect.y - pad and my <= rect.y + rect.h + pad
end

-- How far off the frozen card the pointer may stray and still keep it up: the card opens a little down-
-- right of the cursor, so the hop from unit to card crosses a gap of exactly that offset. Without the
-- slack, reaching for an item icon dismisses the very thing you were reaching for.
local CARD_GRACE = 26

-- The unit whose card is currently open, and the card's own geometry (rect + the item slot rects in it).
-- Held across frames so the card stays up -- and stays PUT -- while the pointer travels from the unit
-- onto it. Public like draft.targets / draft.rects, so a probe or a test can read what the screen is
-- actually offering.
draft.unitCard = nil

function draft.drawTooltip()
    if draft.panel then return end -- the loadout panel owns the screen; its own tooltips run instead
    if draft.drag and draft.drag.active then draft.unitCard = nil; return end -- a drag owns the cursor
    local t = hoveredTarget()
    local mouse = InputMode.isMouse()

    -- Which unit's sheet to show: the one under the pointer, or -- when the pointer has left the unit
    -- but is still on (or just off) the open card -- the one the card is already describing.
    local char, anchor, frozen
    if t and t.kind == "shopUnit" then char = unitInstance(t.ref)
    elseif t and (t.kind == "cell" or t.kind == "benchUnit") and t.unit then char = t.unit end
    -- A card opens over the row beneath it, so its grace band lands squarely on the gear row -- and the
    -- slack exists to cross the gap between a unit and its card, not to swallow the cards under it.
    -- Inside the card proper the card wins (it is what the pointer is actually looking at); once outside
    -- it, anything with a tooltip of its own takes the pointer back and the sheet drops.
    local ownsTooltip = t and (t.kind == "shopGear" or t.kind == "stashGear")
    if char then
        anchor = t
    elseif mouse and draft.unitCard
        and inside(draft.unitCard.rect, draft.mx, draft.my, ownsTooltip and 0 or CARD_GRACE) then
        char, frozen = draft.unitCard.char, draft.unitCard.rect
    end

    if char then
        -- Under the cursor, exactly like a gear tooltip -- the sheet belongs to the thing the pointer is
        -- on, and hunting for it across the screen is not reading. It follows the pointer only while the
        -- pointer is on the unit; the moment it steps off toward the card, the card freezes where it is
        -- so it can be landed on and its kit read a piece at a time. Keyboard/gamepad has no pointer, so
        -- a store unit opens in the free band beside the card rows (the neighbouring offers stay visible)
        -- and a fielded or benched unit opens beside itself.
        local ax, ay, exact
        if frozen then
            ax, ay, exact = frozen.x, frozen.y, true
        elseif mouse and draft.mx then
            ax, ay = draft.mx, draft.my
        elseif anchor.kind == "shopUnit" and draft.storeCardAnchor then
            ax, ay, exact = draft.storeCardAnchor.x, draft.storeCardAnchor.y, true
        else
            ax, ay, exact = anchor.x + anchor.w, anchor.y, true
        end
        local slots = {}
        local rect = drawUnitTooltip(char, ax, ay, slots, exact)

        -- Which piece the pointer is resting on, if any -- the cluster rings that one's card.
        local onSlot
        if mouse then
            for _, s in ipairs(slots) do
                if inside(s, draft.mx, draft.my) then onSlot = s; break end
            end
        end

        -- Every piece it carries, opened at once beside the sheet. A kit too big for the screen leaves
        -- its tail to the old path: point at the icon and that one gets the full card, glossary and all.
        local gear = Character.eachItem(char)
        local shown = drawKitCluster(gear, rect, onSlot and onSlot.item)
        draft.unitCard = { char = char, anchor = anchor, rect = rect, slots = slots, shown = shown }
        if onSlot and not shown[onSlot.item] then
            ItemTooltip.draw(onSlot.item, onSlot.x + onSlot.w, onSlot.y, Scale.WIDTH)
        end
        return
    end

    draft.unitCard = nil
    if not t then return end
    local ax = mouse and (draft.mx or t.x + t.w) or (t.x + t.w)
    local ay = mouse and (draft.my or t.y) or t.y
    if t.kind == "shopGear" then ItemTooltip.draw(gearInstance(t.ref), ax, ay, Scale.WIDTH)
    elseif t.kind == "stashGear" then ItemTooltip.draw(t.ref, ax, ay, Scale.WIDTH)
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

-- The modal card (see the card section above). Its button rects are minted here, the way every other
-- clickable thing on this screen is built where it is drawn, and input reads them back from card.rects.
-- A terminal card blacks the shop out behind it; the others only shade it, because the run they are
-- asking about should stay readable underneath while the player decides.
function draft.drawCard()
    local card = draft.card
    if not card then return end
    love.graphics.setColor(0, 0, 0, card.blackout and 0.78 or 0.6)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    local w, h = 560, 258
    local x, y = Scale.WIDTH / 2 - w / 2, Scale.HEIGHT / 2 - h / 2
    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", x, y, w, h, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", x, y, w, h, Theme.R, Theme.R)
    love.graphics.setFont(titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf(card.title, x, y + 32, w, "center")
    love.graphics.setFont(bodyFont)
    Theme.set(Theme.ink)
    love.graphics.printf(card.body, x + 30, y + 86, w - 60, "center")

    local pad, gap, bh = 26, 14, 44
    local n = #card.buttons
    local bw = (w - pad * 2 - gap * (n - 1)) / n
    local mouse = InputMode.isMouse()
    card.rects = {}
    for i, b in ipairs(card.buttons) do
        local r = {
            x = x + pad + (i - 1) * (bw + gap), y = y + h - 26 - bh, w = bw, h = bh,
            label = b.label, activate = b.activate,
        }
        card.rects[i] = r
        local hovered = mouse and draft.mx and hit(r, draft.mx, draft.my)
        drawButton(r, (mouse and hovered) or (not mouse and draft.cursor == i), hovered)
    end
end

function draft.draw()
    Theme.set(Theme.slot)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    draft.drawHeader()

    if draft.terminal then
        draft.drawCard()
        love.graphics.setColor(1, 1, 1)
        return
    end

    panel(draft.rects.store, "STORE")
    draft.drawFormation()
    panel(draft.rects.stash, "STASH  --  drag gear onto a unit to equip")

    local mouse = InputMode.isMouse()
    for i, t in ipairs(draft.targets) do
        -- Nothing behind a card is focused: the cursor is on the card's buttons, and a highlighted
        -- store card under a modal would read as clickable when it isn't.
        local focused = not draft.card and ((not mouse and draft.cursor == i) or (mouse and t.hovered))
        local dragging = draft.drag and draft.drag.active and draft.drag.origin == t
        if t.kind == "shopUnit" or t.kind == "shopGear" then
            drawShopCard(t, t.ref, focused)
        elseif t.kind == "cell" then
            local frame = select(2, DraftRun.cellToColRow(t.ref)) == 1 and { 0.72, 0.6, 0.4 } or Theme.frame
            drawUnitToken(t, t.unit, FCELL, {
                focused = focused, frame = frame,
                held = (t.unit and (t.unit == draft.held or dragging)),
                merge = mergeCandidate(t.unit),
            })
        elseif t.kind == "benchUnit" then
            drawUnitToken(t, t.unit, BCELL, {
                focused = focused,
                held = (t.unit == draft.held or dragging),
                merge = mergeCandidate(t.unit),
            })
        elseif t.kind == "benchDrop" then
            Theme.set(draft.held and Theme.accentAmber or Theme.frame, 0.4)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", t.x, t.y, t.w, t.w, 6, 6)
        elseif t.kind == "stashGear" then
            drawGearRow(t, t.ref, focused, draft.selectedGear == t.ref, gearMergeCandidate(t.ref))
        elseif t.kind == "sell" then
            local hot = focused or (draft.drag and draft.drag.active and hit(t, draft.mx, draft.my))
            drawButton(t, focused, hot)
        else
            drawButton(t, focused)
        end
    end

    -- Prompt / status line.
    local line = draft.message
    if not line and draft.held then line = "Moving " .. (draft.held.name or "unit") .. " -- pick a cell, the bench, Sell, or a store card of its own kind to buy & combine." end
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

    -- The close button is the shop's own exit; a modal card owns the screen (and carries its own way
    -- out), so it is not offered underneath one.
    if not draft.card then draft.closeButton:draw() end

    -- The dragged card rides the cursor above everything.
    if draft.drag and draft.drag.active then draft.drawDragGhost() end

    draft.drawTooltip()

    -- A resume / abandon card sits over the shop it is asking about.
    if draft.card then draft.drawCard() end

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
            elseif t.kind == "stashGear" then return { kind = "stashGear", item = t.ref }
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
        if drop.kind == "cell" then recruitUnitInto(d.ref, drop.unit, { kind = "cell", cell = drop.cell })
        elseif drop.kind == "benchUnit" then recruitUnitInto(d.ref, drop.unit, { kind = "bench" })
        elseif drop.kind == "bench" then recruitUnit(d.ref, { kind = "bench" })
        elseif drop.kind == "formationArea" then recruitUnit(d.ref) end
    elseif d.kind == "shopGear" then
        if not drop then return end
        if drop.kind == "cell" and drop.unit then recruitGear(d.ref, drop.unit)
        elseif drop.kind == "benchUnit" then recruitGear(d.ref, drop.unit)
        elseif drop.kind == "stashGear" then buyGearOnto(d.ref, drop.item)
        elseif drop.kind == "stashArea" then recruitGear(d.ref, nil) end
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
        elseif drop.kind == "benchUnit" and drop.unit then equipGear(d.ref, drop.unit)
        elseif drop.kind == "stashGear" and drop.item ~= d.ref then mergeGear(d.ref, drop.item) end
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
    if draft.card then
        for _, b in ipairs(draft.card.rects or {}) do
            if hit(b, x, y) then b.activate() return end
        end
        return
    end
    if draft.closeButton and draft.closeButton:mousepressed(x, y, button) then leave() return end

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
    if draft.card then
        for _, b in ipairs(draft.card.rects or {}) do
            if hit(b, x, y) then return "hand" end
        end
        return "arrow"
    end
    if draft.closeButton and draft.closeButton:contains(x, y) then return "hand" end
    for _, t in ipairs(draft.targets) do
        if hit(t, x, y) and t.kind ~= "benchDrop" then return "hand" end
    end
    return "arrow"
end

-- ---------------------------------------------------------------------------
-- Input -- keyboard / gamepad (pick-up / drop)
-- ---------------------------------------------------------------------------

-- Cursoring a modal card's row of buttons: the same three moves for keyboard and pad.
local function cardCursor(d)
    local n = #draft.card.buttons
    return ((draft.cursor - 1 + d) % n) + 1
end

local function cardConfirm()
    local b = draft.card.buttons[draft.cursor] or draft.card.buttons[1]
    if b then b.activate() end
end

local function cardCancel()
    local cancel = draft.card.cancel or leave
    cancel()
end

local function moveCursor(d)
    local n = #draft.targets
    if n == 0 then return end
    draft.cursor = ((draft.cursor - 1 + d) % n) + 1
end

-- Confirm on the cursored target: buy, pick up, drop, equip, or press a button, per its kind.
local function confirm()
    local t = draft.targets[draft.cursor]
    if not t then return end
    if t.kind == "shopUnit" and draft.held and DraftRun.canMergeIdInto(t.ref.id, draft.held) then
        -- Holding a unit and confirming a card of its own kind is the pad/keyboard spelling of dragging
        -- that card onto it: buy and combine in one press. Neither device can drag, so the pick-up the
        -- rest of this screen already uses stands in for the grab.
        recruitUnitInto(t.ref, draft.held)
        draft.held = nil
        return
    end
    if t.kind == "shopGear" and draft.selectedGear and DraftRun.canMergeItems(draft.selectedGear, t.ref) then
        -- The gear-side twin of the block above: holding a stash piece and confirming a store card of the
        -- same item at the same level buys and combines the two in one press.
        buyGearOnto(t.ref, draft.selectedGear)
        return
    end
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
    if draft.card then
        if key == "left" or key == "a" then draft.cursor = cardCursor(-1)
        elseif key == "right" or key == "d" then draft.cursor = cardCursor(1)
        elseif key == "return" or key == "kpenter" or key == "space" then cardConfirm()
        elseif key == "escape" then cardCancel() end
        return
    end
    if key == "escape" then
        if draft.held or draft.selectedGear then draft.held, draft.selectedGear = nil, nil else leave() end
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
    if draft.card then
        if b == "dpleft" then draft.cursor = cardCursor(-1)
        elseif b == "dpright" then draft.cursor = cardCursor(1)
        elseif b == "a" or b == "start" then cardConfirm()
        elseif b == "b" then cardCancel() end
        return
    end
    if b == "b" then
        if draft.held or draft.selectedGear then draft.held, draft.selectedGear = nil, nil else leave() end
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
