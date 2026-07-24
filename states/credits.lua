-- The credits roll, and the last screen in the game.
--
-- Reached from states/game.lua when a quest flagged `endsCampaign` clears its objective and its outro
-- finishes -- the one completion in the game that does not return to the hub. Also reachable with no
-- run behind it (a future "Credits" entry on the main menu), which is why the New Game+ offer is an
-- option passed in rather than something this state assumes.
--
-- Two things it is obliged to do, beyond looking like an ending:
--
--   1. Carry the game-icons.net attribution. The icons ship under CC BY 3.0 and attribution is a
--      CONDITION of that licence, owed to players rather than to the repository. The list is read from
--      data/credits_icons.lua, which `. icon-build` generates in the same pass that writes the doc, so
--      the screen cannot drift out of licence by somebody forgetting to update it.
--   2. Be skippable, at every input. A roll you cannot get out of is the single most reliably hated
--      screen in games.
--
-- Fonts are built in `enter`, not at require-time, so the state loads under the headless suite and
-- `buildLines` below can be tested without a window (see tests/ending_spec.lua).

local State = require("states")
local Scale = require("scale")
local Menu = require("ui.menu")
local InputMode = require("input_mode")

local credits = {}

-- Roll speed in logical pixels per second, and the multiplier while a button is held. The slow rate is
-- deliberately slow -- this is the one screen in the game with nothing to do -- and the hold is what
-- makes that acceptable rather than a hostage situation.
local SCROLL_SPEED = 42
local FAST_MULTIPLIER = 6

-- The band at the bottom reserved for the skip hint, and the distance over which the roll dissolves
-- into it. Without this the rolling lines run straight through the hint -- both are centered text on a
-- flat ground, so they interleave into mush exactly when the player is looking for the way out.
--
-- Done with a painted gradient rather than love.graphics.setScissor, deliberately: scissor rectangles
-- are in REAL WINDOW pixels and ignore the transform scale.lua sets up, so a scissor authored in the
-- 1280x720 logical space lands in the wrong place at every window size but one (and in the letterbox
-- bars at most of them). Everything here stays in logical coordinates.
local FOOTER_H = 46
local FADE_H = 64
local FADE_STEPS = 16

-- Vertical rhythm, in logical pixels. A heading gets air above it; a blank row is half a line.
local LINE_H = 30
local HEADING_H = 44
local BLANK_H = 16
local TITLE_H = 96

-- Build the roll as a flat list of `{ text, kind }`, from the authored credits plus the generated icon
-- attribution appended last. Pure: no love.graphics, no state, safe to call headless -- which is the
-- whole reason the roll's content is assembled here rather than inline in `draw`.
--
-- `iconsDef` is optional; a build with no generated attribution simply rolls without it rather than
-- crashing, the same tolerance models/sprite.lua shows a missing image.
function credits.buildLines(def, iconsDef)
    local out = {}
    local function add(kind, text) out[#out + 1] = { kind = kind, text = text } end

    add("title", def.title or "LoveTactics")
    add("blank")

    for _, section in ipairs(def.sections or {}) do
        if section.heading then add("heading", section.heading) end
        for _, line in ipairs(section.lines or {}) do
            -- `false` is an authored blank row inside a section (see data/credits.lua).
            if line then add("line", line) else add("blank") end
        end
        add("blank")
    end

    -- The licence block, always last and always whole. Assembled from the generated data rather than
    -- written out here, so adding an icon can never leave an artist uncredited.
    if iconsDef and iconsDef.authors then
        add("heading", "Icons")
        add("line", string.format("%d icons from %s", iconsDef.count or 0, iconsDef.source or "game-icons.net"))
        add("line", string.format("licensed under %s", iconsDef.licence or "CC BY 3.0"))
        add("blank")
        for _, author in ipairs(iconsDef.authors) do
            add("line", string.format("%s  --  %d", author.name, author.count))
        end
        add("blank")
        add("line", iconsDef.url or "https://game-icons.net")
        add("blank")
    end

    return out
end

-- Height of one entry, used both to lay the roll out and to measure its total length.
local function lineHeight(entry)
    if entry.kind == "title" then return TITLE_H end
    if entry.kind == "heading" then return HEADING_H end
    if entry.kind == "blank" then return BLANK_H end
    return LINE_H
end

local function totalHeight(lines)
    local h = 0
    for _, entry in ipairs(lines) do h = h + lineHeight(entry) end
    return h
end

credits.totalHeight = totalHeight

-- The offset at which the last line has cleared the top of the screen. Past this the roll is over and
-- the menu takes the screen.
--
-- The roll is drawn starting at `Scale.HEIGHT - offset`, so the final line only leaves the top once the
-- offset exceeds the roll's height PLUS a full screen. Anything less ends the roll with content still
-- on it -- which read as the credits being cut off partway, because they were.
local function rollEnd(lines)
    return totalHeight(lines) + Scale.HEIGHT
end

local function buildMenu()
    local items = {}

    if credits.offerNewGamePlus then
        items[#items + 1] = {
            label = "New Game+",
            action = function()
                local Player = require("models.player")
                Player.newGamePlus()
                State.switch(require("states.hub"))
            end,
        }
    end

    items[#items + 1] = {
        label = "Main Menu",
        action = function() State.switch(require("states.menu")) end,
    }

    return Menu.new(items, { startY = Scale.HEIGHT / 2 + 20 })
end

-- `opts.newGamePlus` offers the carry-forward run; omit it (viewing the roll with no run behind it)
-- and only Main Menu is shown.
--
-- Note the `self` first parameter: State.switch calls `state.enter(state, ...)`, so a state's own table
-- always arrives ahead of the caller's arguments (states/init.lua). Dropping it silently shifts every
-- argument by one -- which is exactly how this shipped its first build offering no New Game+ at all.
function credits.enter(self, opts)
    opts = opts or {}
    credits.offerNewGamePlus = opts.newGamePlus and true or false

    -- The one track in the game authored NOT to loop (data/sounds.lua): a credits bed that starts
    -- again under a roll which has already finished is worse than silence.
    require("models.sound").music("music.credits")

    credits.titleFont = credits.titleFont or love.graphics.newFont(52)
    credits.headingFont = credits.headingFont or love.graphics.newFont(24)
    credits.lineFont = credits.lineFont or love.graphics.newFont(18)
    credits.hintFont = credits.hintFont or love.graphics.newFont(15)

    local def = require("data.credits")
    local ok, iconsDef = pcall(require, "data.credits_icons")
    credits.lines = credits.buildLines(def, ok and iconsDef or nil)

    credits.offset = 0
    credits.fast = false
    credits.done = false
    credits.widget = nil
end

-- Jump straight to the end of the roll. Skipping does not skip the SCREEN -- the menu still comes up,
-- because the player still has to choose what happens next.
local function finish()
    if credits.done then return end
    credits.done = true
    credits.offset = rollEnd(credits.lines)
    credits.widget = buildMenu()
end

function credits.update(dt)
    if credits.done then
        credits.widget:update(dt)
        return
    end

    local speed = SCROLL_SPEED * (credits.fast and FAST_MULTIPLIER or 1)
    credits.offset = credits.offset + speed * dt
    if credits.offset >= rollEnd(credits.lines) then finish() end
end

-- The ground colour, painted as the background and reused by the fades so they dissolve INTO the page
-- rather than toward some other black.
local GROUND = { 0.06, 0.06, 0.09 }

-- A vertical gradient of the ground colour, `from` -> `to` alpha over `h` pixels starting at `y`.
-- Stepped rectangles rather than a mesh: sixteen bands is under the eye's threshold at this contrast
-- and needs no vertex buffer to maintain.
local function fade(y, h, from, to)
    local step = h / FADE_STEPS
    for i = 0, FADE_STEPS - 1 do
        local t = i / (FADE_STEPS - 1)
        love.graphics.setColor(GROUND[1], GROUND[2], GROUND[3], from + (to - from) * t)
        love.graphics.rectangle("fill", 0, y + i * step, Scale.WIDTH, step + 1)
    end
end

function credits.draw()
    love.graphics.setColor(GROUND)
    love.graphics.rectangle("fill", 0, 0, Scale.WIDTH, Scale.HEIGHT)

    if not credits.done then
        local y = Scale.HEIGHT - credits.offset
        for _, entry in ipairs(credits.lines) do
            local h = lineHeight(entry)
            -- Only draw what is on screen. The roll is a few hundred rows long and printf on each of
            -- them every frame is work for nobody.
            if y > -h and y < Scale.HEIGHT then
                if entry.kind == "title" then
                    love.graphics.setFont(credits.titleFont)
                    love.graphics.setColor(0.95, 0.85, 0.55)
                    love.graphics.printf(entry.text, 0, y, Scale.WIDTH, "center")
                elseif entry.kind == "heading" then
                    love.graphics.setFont(credits.headingFont)
                    love.graphics.setColor(0.72, 0.66, 0.48)
                    love.graphics.printf(entry.text, 0, y + 10, Scale.WIDTH, "center")
                elseif entry.kind == "line" then
                    love.graphics.setFont(credits.lineFont)
                    love.graphics.setColor(0.82, 0.83, 0.88)
                    love.graphics.printf(entry.text, 0, y, Scale.WIDTH, "center")
                end
            end
            y = y + h
        end

        -- Lines dissolve as they arrive at the footer and again as they leave the top, so nothing is
        -- ever chopped mid-glyph and nothing ever reaches the hint.
        local footerTop = Scale.HEIGHT - FOOTER_H
        love.graphics.setColor(GROUND[1], GROUND[2], GROUND[3], 1)
        love.graphics.rectangle("fill", 0, footerTop, Scale.WIDTH, FOOTER_H)
        fade(footerTop - FADE_H, FADE_H, 0, 1)
        fade(0, FADE_H, 1, 0)
    else
        love.graphics.setFont(credits.titleFont)
        love.graphics.setColor(0.95, 0.85, 0.55)
        love.graphics.printf("LoveTactics", 0, Scale.HEIGHT / 2 - 130, Scale.WIDTH, "center")
        love.graphics.setFont(credits.lineFont)
        love.graphics.setColor(0.65, 0.67, 0.75)
        love.graphics.printf("Thank you for playing.", 0, Scale.HEIGHT / 2 - 56, Scale.WIDTH, "center")
        credits.widget:draw()
    end

    -- The skip affordance, named for whichever device is driving. Kept on screen for the whole roll:
    -- a hint that fades out is a hint the player discovers they needed after it is gone.
    if not credits.done then
        love.graphics.setFont(credits.hintFont)
        love.graphics.setColor(0.45, 0.47, 0.55)
        local hint = InputMode.isGamepad()
            and "A: hold to speed up    B: skip"
            or "Hold click or Space: speed up    Esc: skip"
        love.graphics.printf(hint, 0, Scale.HEIGHT - 34, Scale.WIDTH, "center")
    end

    love.graphics.setColor(1, 1, 1)
end

-- ---------------------------------------------------------------------------
-- Input -- mouse, keyboard and gamepad, the project standard (see CLAUDE.md).
-- Every device can both speed the roll up and skip it outright.
-- ---------------------------------------------------------------------------

function credits.keypressed(key)
    if credits.done then
        credits.widget:keypressed(key)
        return
    end
    if key == "escape" then finish() else credits.fast = true end
end

function credits.keyreleased()
    credits.fast = false
end

function credits.mousepressed(x, y, button)
    if credits.done then
        credits.widget:mousepressed(x, y, button)
        return
    end
    credits.fast = true
end

function credits.mousereleased()
    credits.fast = false
end

function credits.mousemoved(x, y)
    if credits.done then credits.widget:mousemoved(x, y) end
end

-- Hand over a menu button once the roll has finished (see ui/cursor.lua).
function credits:cursorKind(x, y)
    if credits.done and credits.widget:mouseOverItem(x, y) then return "hand" end
    return "arrow"
end

function credits.gamepadpressed(joystick, button)
    if credits.done then
        credits.widget:gamepadpressed(joystick, button)
        return
    end
    if button == "b" then finish() else credits.fast = true end
end

function credits.gamepadreleased()
    credits.fast = false
end

return credits
