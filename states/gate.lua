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
local Player = require("models.player")
local Scale = require("scale")
local Menu = require("ui.menu")
local Theme = require("ui.theme")

local gate = {}

local titleFont = Theme.display(34)
local headFont = Theme.display(17)
local bodyFont = Theme.body(14)
local smallFont = Theme.body(13)

-- ---------------------------------------------------------------------------
-- Going down
-- ---------------------------------------------------------------------------


-- ---------------------------------------------------------------------------
-- Going down, and starting over
-- ---------------------------------------------------------------------------

local function descend()
    gate.panel = nil
    local run = gate.run or Descent.new(gate.player)
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
function gate:build()
    local items = {}
    if Gate.canDescend(gate.player) then
        items[#items + 1] = {
            label = "Down to floor " .. Descent.depth(gate.run),
            action = descend,
        }
    end
    items[#items + 1] = { label = "Back to the City", action = function()
        State.switch(require("states.hub"))
    end }
    gate.menu = Menu.new(items, { startY = 420, buttonHeight = 52, spacing = 16 })
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
end

function gate.update(dt)
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

    -- THE COMPANY, because the last thing a player wants before committing to a floor is the shape the
    -- company is in. Health as a fraction rather than a bar: this is a ledger, not a fight, and the
    -- number is what a decision about going one floor deeper is actually made on.
    local p = gate.player or {}
    love.graphics.setFont(headFont)
    Theme.set(Theme.ink)
    love.graphics.printf("The Company", Scale.WIDTH / 2 - 340, 178, 330, "left")
    love.graphics.setFont(bodyFont)
    local y = 208
    local Wound = require("models.wound")
    for _, char in ipairs(p.roster or {}) do
        local hp = char.stats and char.stats.health
        local cur = (type(hp) == "table" and hp.current) or 0
        local max = (type(hp) == "table" and hp.max) or 0
        local wounds = Wound.count(p, char.id)
        Theme.set(Theme.ink)
        love.graphics.printf((char.name or char.id) .. "  lv " .. (char.level or 1),
            Scale.WIDTH / 2 - 340, y, 220, "left")
        Theme.set(wounds > 0 and Theme.accentWeapon or Theme.muted)
        love.graphics.printf(cur .. " / " .. max .. (wounds > 0 and ("   wounded x" .. wounds) or ""),
            Scale.WIDTH / 2 - 120, y, 210, "left")
        y = y + 22
    end
    if #(p.roster or {}) == 0 then
        Theme.set(Theme.muted)
        love.graphics.printf("Nobody.", Scale.WIDTH / 2 - 340, y, 300, "left")
    end

    love.graphics.setFont(headFont)
    Theme.set(Theme.accentAmber)
    love.graphics.printf((p.gold or 0) .. " gold", Scale.WIDTH / 2 + 40, 178, 300, "right")

    if gate.menu then gate.menu:draw() end
    if gate.panel then gate.panel:draw() end
end

-- ---------------------------------------------------------------------------
-- Input: the panel owns it while one is open, else the menu
-- ---------------------------------------------------------------------------

local function route(name, ...)
    local target = gate.panel or gate.menu
    if target and target[name] then return target[name](target, ...) end
end

function gate.mousemoved(x, y) return route("mousemoved", x, y) end
function gate.mousepressed(x, y, b) return route("mousepressed", x, y, b) end
function gate.wheelmoved(dx, dy) return route("wheelmoved", dx, dy) end
function gate:cursorKind(x, y)
    local target = gate.panel or gate.menu
    if target and target.cursorKind then return target:cursorKind(x, y) end
    return "arrow"
end

function gate.keypressed(key)
    if gate.panel then return route("keypressed", key) end
    if key == "escape" then return State.switch(require("states.hub")) end
    return route("keypressed", key)
end

function gate.gamepadpressed(joystick, button)
    if gate.panel then return route("gamepadpressed", joystick, button) end
    if button == "b" then return State.switch(require("states.hub")) end
    return route("gamepadpressed", joystick, button)
end

return gate
