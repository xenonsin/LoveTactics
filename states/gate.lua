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
-- AFTER A WIPE this is where the game lands -- at the temple, with the whole company alive, wounded, and
-- carrying nothing. Everything they had is in a heap on the floor they fell on (models/descent.lua's
-- `drops`), so the next expedition has somewhere it very much wants to go. Dark Souls' bloodstain, and
-- the only thing that stops "climb out" and "die" being the same move.

local State = require("states")
local Choice = require("ui.panels.choice")
local Descent = require("models.descent")
local Gate = require("models.gate")
local Mule = require("models.mule")            -- what comes back up the stair, and how wide it is
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
    -- WAIT A DAY, and it draws only when there is something to wait FOR.
    --
    -- Days advance on walking into the stair, so a company too hurt to send has no way to reach the
    -- morning it is waiting for -- which is a softlock wearing the clothes of a hard decision. This is
    -- the way out, and what it costs is what any night costs: the bodies in the beds are out of the
    -- company for one more of them.
    --
    -- THROUGH Gate.night, not the three calls spelled out again. It used to spend the day, rest the
    -- wounds and discharge the mended inline -- a fourth copy of the beat, written before there was one
    -- definition of a night (models/gate.lua). Player.restore stays here rather than moving in there:
    -- waiting at the Gate is standing in a town, and Gate.rest tops the company up for the same reason.
    --
    -- Hidden unless somebody is actually IN A BED, rather than merely hurt. Waiting mends nobody who is
    -- not lodged, so offering it to a company with three wounded and none of them at the Inn is a button
    -- that spends a day for nothing. A control draws where it can be used.
    if #Gate.lodged(gate.player) > 0 then
        items[#items + 1] = {
            label = "Wait a day",
            action = function()
                Gate.night(gate.player)
                Player.restore(gate.player)
                Player.save()
                gate:build()
            end,
        }
    end
    -- WIDEN THE MULE (models/mule.lua). Drawn only where the move is legal -- there is a rung above the
    -- one this company stands on, and the gold is in hand -- rather than as a greyed plate quoting a
    -- price nobody can pay. A company that cannot afford it is told by the row not being there, which is
    -- the same rule "Wait a day" above is drawn under.
    --
    -- HERE RATHER THAN IN THE CITY because this is the counter the mule is standing at: it is the thing
    -- that carries what comes back up this stair, and the decision to widen it is made looking at the
    -- hole. The Forge bills in technique and the shops in standing; this is gold, plainly, for a bigger
    -- bag.
    local nextRung = Mule.nextRung(gate.player)
    if nextRung and (gate.player.gold or 0) >= nextRung.price then
        items[#items + 1] = {
            label = "Widen the mule  " .. Mule.capacity(gate.player) .. " \226\134\146 " ..
                nextRung.capacity .. "   (" .. nextRung.price .. "g)",
            action = function()
                if Mule.upgrade(gate.player) then
                    Player.save()
                    gate:build()
                end
            end,
        }
    end
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
