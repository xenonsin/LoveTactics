-- The deployment phase's KEYBOARD AND PAD reach (ui/deploy_phase.lua).
--
-- docs/deployment.md has claimed "keyboard and pad reach all of it" since the company strip went, and
-- it was prose with nothing under it: Reset Line had no key and no button, so the one control that
-- undoes a shuffle was mouse-only on a screen whose whole subject is shuffling. The selection ring
-- (a step LEFT off the board crosses into the control stack) is what makes the claim true for every
-- plate at once, and this is what stops the next plate added to that stack from quietly falling off it.
--
-- Constructed by hand rather than through DeployPhase.new, which builds fonts -- love.graphics.newFont
-- throws under the headless runner (see tests/ui_load_spec.lua). Everything pinned here is geometry and
-- dispatch, which is exactly the half that has no window in it.

local DeployPhase = require("ui.deploy_phase")

-- A board that clamps at its edges, which is the whole of what the crossing reads (a step left that
-- moves nothing is a step off the board). The real one turns the step through the board's facing first
-- (BattleMap:moveCursor); the clamp is the same either way.
local function stubMap(cols, rows)
    return {
        size = 48,
        cols = cols or 8,
        rows = rows or 8,
        cursor = { x = 1, y = 1 },
        moveCursor = function(self, dx, dy)
            self.cursor.x = math.max(1, math.min(self.cols, self.cursor.x + dx))
            self.cursor.y = math.max(1, math.min(self.rows, self.cursor.y + dy))
        end,
        cellToPixel = function(self, x, y) return 200 + (x - 1) * self.size, 100 + (y - 1) * self.size end,
    }
end

local function phase(opts)
    opts = opts or {}
    return setmetatable({
        column = { x = 16, y = 104, w = 130 },
        placed = opts.placed or { { char = "knight", x = 1, y = 1 } },
        roster = {},
        allowAuto = opts.allowAuto ~= false,
        autoBattle = opts.autoBattle or false,
        autoSpeed = 1,
        speedSteps = { 1, 2, 3 },
        onLoadout = opts.onLoadout,
        map = opts.map or stubMap(),
    }, DeployPhase)
end

-- Walk the ring the way a player would -- into the column, then every direction from every plate --
-- and collect the keys it can actually land on.
local function reachable(p)
    p.focus = nil
    p:navigate(-1, 0) -- off the board's left edge, into the stack
    local seen, frontier = {}, {}
    if not p.focus then return seen end
    seen[p.focus] = true
    frontier[#frontier + 1] = p.focus
    while #frontier > 0 do
        local from = table.remove(frontier)
        for _, step in ipairs({ { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }) do
            p.focus = from
            p:navigateColumn(step[1], step[2])
            if p.focus and not seen[p.focus] then
                seen[p.focus] = true
                frontier[#frontier + 1] = p.focus
            end
        end
    end
    return seen
end

return {
    {
        name = "every control in the stack is reachable by the keyboard/pad selection",
        fn = function()
            -- The fullest stack the phase can show: a fight with a stash behind it, auto armed (which
            -- is the only state the speed cycler exists in).
            local p = phase({ onLoadout = function() end, autoBattle = true })
            local seen = reachable(p)
            for _, c in ipairs(p:controls()) do
                assert(seen[c.key], "control '" .. c.key .. "' cannot be reached without a mouse")
            end
        end,
    },
    {
        name = "Reset Line is reachable -- it is the plate that had no binding of its own",
        fn = function()
            local p = phase()
            assert(reachable(p)["autofill"], "Reset Line is mouse-only again")

            -- And it answers a key, for the hand already on the arrows.
            local hit = false
            p.autoFill = function() hit = true end
            p:keypressed("r")
            assert(hit, "R did not press Reset Line")
        end,
    },
    {
        name = "a stack with no Loadout and no Auto is still fully reachable",
        fn = function()
            -- A probe or a tutorial fight: no stash to open, auto forbidden. Nothing but Reset Line
            -- and the bell, and a ring that only worked on the long stack would strand both.
            local p = phase({ allowAuto = false })
            local seen = reachable(p)
            for _, c in ipairs(p:controls()) do
                assert(seen[c.key], "control '" .. c.key .. "' is stranded on the short stack")
            end
        end,
    },
    {
        name = "the board's left edge is the crossing, and the stack's right edge is the way back",
        fn = function()
            local p = phase()
            p.map.cursor.x, p.map.cursor.y = 3, 3
            p:navigate(-1, 0)
            assert(p.focus == nil, "a step left INSIDE the board should move the cursor, not cross")
            assert(p.map.cursor.x == 2, "the cursor did not step left")

            p:navigate(-1, 0)
            assert(p.focus == nil, "still inside the board")
            p:navigate(-1, 0)
            assert(p.focus ~= nil, "a step left off the board should enter the control stack")

            -- Off the right of a plate that has nothing beside it: back to the board, cursor intact.
            p:navigate(1, 0)
            assert(p.focus == nil, "a step right off the stack should give the board its cursor back")
            assert(p.map.cursor.x == 1, "crossing back must not move the board cursor")
        end,
    },
    {
        name = "the speed cycler sits BESIDE the auto switch, not under it",
        fn = function()
            local p = phase({ autoBattle = true })
            p.focus = "auto"
            p:navigateColumn(0, 1)
            assert(p.focus == "begin", "down from Auto should reach the bell, not the cycler")
            p.focus = "auto"
            p:navigateColumn(1, 0)
            assert(p.focus == "speed", "right from Auto should reach the cycler it is paired with")
            p:navigateColumn(-1, 0)
            assert(p.focus == "auto", "left from the cycler should come back to the switch")
        end,
    },
    {
        name = "a focused plate that disappears hands the selection on, never drops it",
        fn = function()
            -- V throws the auto switch off while the selection is sitting on the cycler paired to it.
            local p = phase({ autoBattle = true })
            p.focus = "speed"
            p.autoBattle = false
            local c = p:focused()
            assert(c ~= nil, "the selection vanished with the control it was on")
            assert(c.key == "auto", "it should fall back to the switch whose row the cycler shared")
        end,
    },
    {
        name = "confirm presses the focused plate, and a disabled one is not a plate",
        fn = function()
            local p = phase({ onLoadout = function() end })
            local opened = false
            p.onLoadout = function() opened = true end
            p.focus = "loadout"
            p:confirm()
            assert(opened, "confirm on the Loadout plate did not open it")

            -- The bell with nobody on the field: greyed, and confirm must not ring it.
            local q = phase({ placed = {} })
            local rung = false
            q.onCommit = function() rung = true end
            q.focus = "begin"
            q:confirm()
            assert(not rung, "confirm rang a bell that cannot be rung")
        end,
    },
    {
        name = "back steps out of the column, then out of the hand, then says what it wants",
        fn = function()
            local p = phase()
            p.focus, p.held = "begin", "knight"
            p:cancel()
            assert(p.focus == nil, "back should leave the column first")
            assert(p.held == "knight", "leaving the column must not drop the body in hand")
            p:cancel()
            assert(p.held == nil, "back should then set the carried body down where it stood")
            assert(p.message == nil, "putting a body back is not a refusal to explain")
            p:cancel()
            assert(p.message ~= nil, "with nothing to back out of, back should say what the phase wants")
        end,
    },
    {
        name = "the pad's B and the keyboard's Esc are the same ladder",
        fn = function()
            local a, b = phase(), phase()
            a.focus, a.held = "begin", "knight"
            b.focus, b.held = "begin", "knight"
            a:keypressed("escape")
            b:gamepadpressed(nil, "b")
            assert(a.focus == b.focus and a.held == b.held,
                "Esc and B disagreed about what backing out means")
        end,
    },
}
