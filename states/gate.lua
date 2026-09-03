-- THE GATE: the town at the mouth of the descent, and the other half of the loop.
--
-- A descent used to be one push with no way to stop pushing. It has a way out now -- you walk back to
-- the stair you came down by (states/game.lua's `ascent` stop) -- and this is what is up there when you
-- do: a hole in the ground, and a look at the company before they go back into it.
--
--   the roster    who is going down, and what shape they are in
--   the stair     back down to the floor the company climbed out of
--
-- AND NOTHING ELSE. The inn, the store and the hiring hall were rows on this menu once, which put three
-- towns' worth of business at the mouth of a stair. They are cards in the CITY now (data/buildings/),
-- and the split is the reference's own: Wizardry's castle holds the tavern, the inn, Boltac's and the
-- temple, and the dungeon entrance sits at the edge of town where there is nothing to do but enter.
--
-- AFTER A WIPE this is where the game lands -- at the temple, with the whole company alive, whole, and
-- carrying nothing. Whole because being above ground is what sets a bone now (models/wound.lua), so
-- what a wipe takes is the haul and the run and not the bodies' next expedition as well.
-- Everything they had is in a heap on the floor they fell on (models/descent.lua's
-- `drops`), so the next expedition has somewhere it very much wants to go. Dark Souls' bloodstain, and
-- the only thing that stops "climb out" and "die" being the same move.

local State = require("states")
local Choice = require("ui.panels.choice")
local Descent = require("models.descent")
local Gate = require("models.gate")
local Player = require("models.player")
local Scale = require("scale")
local Menu = require("ui.menu")
local Theme = require("ui.theme")
local SeedReadout = require("ui.seed_readout") -- the numbers behind the stair, in a dev build only
local Picker = require("ui.expedition_picker") -- four plates over the company; who goes down

local gate = {}

local titleFont = Theme.display(34)
local headFont = Theme.display(17)
local bodyFont = Theme.body(14)
local smallFont = Theme.body(13)

-- Iselle's tally, in the right-hand column under the purse. Beside the gold rather than over the stair
-- on purpose: this screen is a LEDGER the player reads before committing, and the tally is the other
-- entry in it. Held at file scope so the arrival beat fires on a real change (ui/count_meter.lua).
local countMeter = require("ui.count_meter").new()

-- ---------------------------------------------------------------------------
-- Going down
-- ---------------------------------------------------------------------------


-- ---------------------------------------------------------------------------
-- Going down, and starting over
-- ---------------------------------------------------------------------------

-- THE STAIR IS WHERE AN EXPEDITION BEGINS, so it is where the rollback point is taken.
--
-- `run.entry` is the company exactly as it walked in, and what a wipe puts on the floor is measured
-- against it (Player.takeAtRisk). Clearing it here makes states/game.lua's enter take a fresh one at the
-- mouth of the floor, which is the only reading of "what this expedition found" a player would accept:
-- the blade bought at the store, the body pulled at the hall and the night at the inn all happened in
-- TOWN, with banked gold, and none of them is a find that a bad fight downstairs can spill.
--
-- Carrying the climb-out snapshot back down instead -- which is what happened before, since the run
-- keeps `entry` and enter only falls back when it is nil -- meant everything bought between two
-- descents was still provisional, and a company that spent its winnings kitting out at the Gate would
-- lose the kit on the next floor. Climbing out banks; going down starts the next bet.
--
-- Floor to floor is untouched: that is a fresh enter with no Gate in between, `run.entry` is still set,
-- and re-snapshotting there would bank a run's finds just for walking downstairs.
local function descend()
    gate.panel = nil
    local run = gate.run or Descent.new(gate.player)
    run.entry = nil
    Player.active = gate.player
    State.switch(require("states.game"), Descent.floorQuest(run, gate.player), nil, gate.player)
end

-- ---------------------------------------------------------------------------
-- The screen
-- ---------------------------------------------------------------------------

-- ONE THING HAPPENS HERE AND IT IS GOING DOWN.
--
-- This screen carried the inn, the store and the hiring hall as menu rows, which was three towns' worth
-- of business conducted at the mouth of a stair. They are cards in the CITY now (data/buildings/), and
-- the split is the reference's own: Wizardry's castle holds the tavern, the inn, Boltac's and the
-- temple, and the dungeon entrance sits out at the edge of town where there is nothing to do but enter.
--
-- What is left is the stair, the way back, and a readout of who is about to walk down it -- which stays
-- because the last thing a player wants before committing is to see the shape their company is in.
-- THE PICKER IS A BOARD, NOT A LIST (ui/expedition_picker.lua).
--
-- This asked with toggle rows first, and rows are the wrong shape for it. A party has POSITIONS in it
-- and a company is a thing you look across; a column of ticked labels says neither, and reads as a
-- settings screen for a decision that is really "these four, and that one stays home". Four plates over
-- the roster says it in one glance, and the body moves between them.
--
-- The two actions stay a menu underneath. Tab (or a shoulder) moves focus between the two, which is the
-- same hand-off ui/panels/party.lua keeps between a character's grid and the stash.
function gate:build()
    gate.picker = Picker.new({
        x = Scale.WIDTH / 2 - 260, y = 206,
        player = gate.player, run = gate.run,
        onChange = function() gate:build() end,
    })

    local items = {}
    if Gate.canDescend(gate.player, gate.run) then
        items[#items + 1] = {
            label = "Down to floor " .. Descent.depth(gate.run),
            action = descend,
        }
    end
    -- THERE IS NO "WAIT A DAY" ROW, and its deletion is the design rather than a tidy-up.
    --
    -- It existed to let a company too hurt to descend reach the morning that would mend them, because
    -- the only other way to spend a day was to walk into the stair -- a cure on the far side of the
    -- fight you were too hurt to take. Nothing waits for a morning any more: the surface sets every bone
    -- the moment the company is standing on it (Wound.clear, in gate.enter below), so a button that
    -- spends a day and mends nobody is a control with nothing left to do. A control draws where it can
    -- be used, and this one no longer can be.
    --
    -- AND NOTHING IS SOLD HERE EITHER. "Widen the mule" was a row on this menu and is gone for the same
    -- reason the inn and the store are: this screen is a hole in the ground and a look at the company,
    -- not a counter. The mule's ladder (models/mule.lua) still exists -- it just does not get bought at
    -- the mouth of the stair.
    items[#items + 1] = { label = "Back to the City", action = function()
        State.switch(require("states.hub"))
    end }
    gate.menu = Menu.new(items, {
        startY = gate.picker.y + gate.picker:height() + 28,
        buttonHeight = 44, spacing = 12,
    })
    gate.focus = gate.focus or "picker"
end

function gate.enter(self, opts)
    opts = opts or {}
    gate.player = opts.player or Player.active
    -- STANDING HERE IS BEING OUT OF THE HOLE, so the dive's injuries end here (models/wound.lua's
    -- Wound.clear) and the company is topped back up to the ceiling that leaves them.
    --
    -- BOTH TOWN SCREENS DO THIS, not one, and the pair is not redundant: a company that takes the stair
    -- up lands here, a company that is beaten on campaign ground lands in the city (states/hub.lua does
    -- the same two calls at its own door), and a wiped descent lands here with `opts.wiped` set. Whoever
    -- arrives first sets the bones; the other finds nothing to do and costs a table walk.
    require("models.wound").clear(gate.player)
    Player.restore(gate.player)
    -- THE RUN LIVES ON THE PLAYER, and that is the whole of the descent joining the campaign save.
    --
    -- It used to be a throwaway profile in a file of its own (Descent.FILE), because the descent was a
    -- separate game mode that banked nothing. It is the game now: the prologue's avatar and the Rowan
    -- sworn beside her walk into this city and down this stair, so there is ONE company, ONE save, and
    -- the floor stack rides on the player like everything else it owns.
    gate.run = opts.run or gate.player.descentRun or Descent.new(gate.player)
    gate.player.descentRun = gate.run
    gate.panel = nil
    gate.wiped = opts.wiped
    gate.notice = opts.wiped
        and ("The company went down on floor " .. opts.wiped ..
             ". They are still there, and so is everything they were carrying.")
        or nil
    require("models.sound").music("music.menu")
    require("ui.screen_fx").reset()
    gate:build()

    -- SHE EXPLAINS THE TALLY, ONCE, THE FIRST TIME THEY COME BACK UP EARLY. The mark that opens the
    -- readout is set the instant the stair is taken (states/game.lua), so by the time this runs the
    -- marks are already on screen and she has something to point at. The second mark is set when the
    -- scene has actually finished, which is what survives a player quitting in the middle of it.
    --
    -- Not gated on `opts` for that reason: a flag passed through the switch would be gone on the next
    -- load, and this is the only place the mechanic is ever explained.
    if Descent.everClimbedOut(gate.player) and not Descent.tallyTaught(gate.player) then
        require("models.conversation").play("conversation_rift_tally", function()
            Descent.markTallyTaught(gate.player)
            Player.save()
        end)
    end
end

function gate.update(dt)
    countMeter:update(dt)
    if gate.panel then
        if gate.panel.update then gate.panel:update(dt) end
    elseif gate.menu then
        gate.menu:update(dt)
    end
end

function gate.draw()
    Theme.drawMount(Scale.WIDTH, Scale.HEIGHT)

    love.graphics.setFont(titleFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf("The Gate", 0, 48, Scale.WIDTH, "center")

    love.graphics.setFont(smallFont)
    Theme.set(Theme.muted)
    love.graphics.printf("A counter, a lamp, and a hole in the ground.", 0, 94, Scale.WIDTH, "center")

    if gate.notice then
        love.graphics.setFont(bodyFont)
        Theme.set(Theme.accentAmber)
        love.graphics.printf(gate.notice, Scale.WIDTH / 2 - 340, 126, 680, "center")
    end

    -- WHO GOES DOWN, and the count is the whole header. The list itself is the menu (gate:build's
    -- rosterRows) -- it reads and it chooses, because drawing the eight names twice to do those two
    -- jobs separately would be two lists of the same company.
    --
    -- The count is here rather than on a row because it is the thing that explains a press that did
    -- nothing: at four of four, another name simply does not take.
    local p = gate.player or {}
    love.graphics.setFont(headFont)
    Theme.set(Theme.ink)
    local going = #Descent.party(gate.run, gate.player)
    love.graphics.printf("Who goes down   " .. going .. " / " .. Descent.PARTY_MAX,
        Scale.WIDTH / 2 - 340, 178, 330, "left")
    if #(p.roster or {}) == 0 then
        love.graphics.setFont(bodyFont)
        Theme.set(Theme.muted)
        love.graphics.printf("Nobody.", Scale.WIDTH / 2 - 340, 208, 300, "left")
    elseif gate.picker then
        gate.picker:draw()
    end

    love.graphics.setFont(headFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf((p.gold or 0) .. " gold", Scale.WIDTH / 2 + 40, 178, 300, "right")

    -- ...and the other half of the ledger, once she has explained what it is (Descent.everClimbedOut).
    if Descent.everClimbedOut(p) and gate.run then
        countMeter:draw(Scale.WIDTH / 2 + 40, 250, 300, gate.player)
    end

    if gate.menu then gate.menu:draw() end

    -- The hovered body's card, LAST of the screen's own layers. A full one is most of the screen tall
    -- (ui/body_tooltip.lua), so drawn with the company it would be clipped by the two buttons under it;
    -- and it is skipped entirely while a panel is up, since a modal owns the screen it opened over.
    if gate.picker and not gate.panel then gate.picker:drawHover() end

    if gate.panel then gate.panel:draw() end

    -- The numbers behind the stair, in a development build only (ui/seed_readout.lua). Here as well as
    -- on the board because this is the screen a descent is COMMITTED from: the rift below is dealt
    -- before the stair is taken, so a run can be written down -- or recognised as one already seen --
    -- without walking into it first.
    SeedReadout.draw(gate.player, gate.run)
end

-- ---------------------------------------------------------------------------
-- Input: the panel owns it while one is open, else the menu
-- ---------------------------------------------------------------------------

local function route(name, ...)
    local target = gate.panel or gate.menu
    if target and target[name] then return target[name](target, ...) end
end

-- THE PICKER GETS FIRST REFUSAL ON THE MOUSE, and the menu takes whatever it declines. A pointer needs
-- no focus model -- it is already pointing at the thing it means -- so the Tab hand-off below exists
-- only for the two inputs that cannot.
local function pickerFirst(name, ...)
    if gate.panel then return route(name, ...) end
    local p = gate.picker
    if p and p[name] and p[name](p, ...) then return true end
    return route(name, ...)
end

function gate.mousemoved(x, y)
    if not gate.panel and gate.picker then gate.picker:mousemoved(x, y) end
    return route("mousemoved", x, y)
end
function gate.mousepressed(x, y, b) return pickerFirst("mousepressed", x, y, b) end
function gate.mousereleased(x, y, b)
    if gate.panel then return route("mousereleased", x, y, b) end
    if gate.picker then return gate.picker:mousereleased(x, y, b) end
end
function gate.wheelmoved(dx, dy) return route("wheelmoved", dx, dy) end
function gate:cursorKind(x, y)
    local target = gate.panel or gate.menu
    if target and target.cursorKind then return target:cursorKind(x, y) end
    return "arrow"
end

-- TAB AND THE SHOULDERS MOVE BETWEEN THE TWO HALVES of this screen -- the plates and the two actions --
-- which is the hand-off ui/panels/party.lua already keeps between a character's grid and the stash. It
-- exists for the keyboard and the pad alone; a pointer is always already on the half it means.
local function toggleFocus()
    gate.focus = (gate.focus == "menu") and "picker" or "menu"
    return true
end

function gate.keypressed(key)
    if gate.panel then return route("keypressed", key) end
    if key == "escape" then
        -- A held body is put down before the screen is left, or Escape would mean two things at once.
        if gate.picker and gate.picker.held then gate.picker.held = nil return true end
        return State.switch(require("states.hub"))
    end
    if key == "tab" then return toggleFocus() end
    if gate.focus == "picker" and gate.picker and gate.picker:keypressed(key) then return true end
    return route("keypressed", key)
end

function gate.gamepadpressed(joystick, button)
    if gate.panel then return route("gamepadpressed", joystick, button) end
    if button == "leftshoulder" or button == "rightshoulder" then return toggleFocus() end
    if button == "b" then
        if gate.picker and gate.picker.held then gate.picker.held = nil return true end
        return State.switch(require("states.hub"))
    end
    if gate.focus == "picker" and gate.picker
        and gate.picker:gamepadpressed(joystick, button) then return true end
    return route("gamepadpressed", joystick, button)
end

return gate
