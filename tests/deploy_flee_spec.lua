-- THE RUN AWAY PLATE'S NOTE (ui/deploy_phase.lua's fleeNotePlate).
--
-- The plate quotes a price -- "Run Away (55%)" -- and names no stake, and the three things that decide
-- whether pressing it is sane are all off-screen: one attempt only, a loss opens the SAME fight from
-- behind rather than cancelling it, and the odds run the wrong way on purpose (models/flee.lua). The
-- note beside the plate is where those live, so what is pinned here is that it can be REACHED: on a
-- pad, which has no pointer to hover with, exactly as on a mouse.
--
-- Driven through fleeNotePlate rather than drawFleeNote, which is why the gating is decided apart from
-- the drawing: the answer IS what the player gets, and it can be read here without a window.
--
-- Constructed by hand rather than through DeployPhase.new, as tests/deploy_input_spec.lua does and for
-- the same reason (the constructor builds fonts, and love.graphics.newFont throws headless).

local DeployPhase = require("ui.deploy_phase")
local InputMode = require("input_mode")

local function phase(opts)
    opts = opts or {}
    return setmetatable({
        column = { x = 16, y = 104, w = 130 },
        placed = { { char = "knight", x = 1, y = 1 } },
        roster = {},
        allowAuto = true,
        autoBattle = false,
        autoSpeed = 1,
        speedSteps = { 1, 2, 3 },
        onFlee = opts.onFlee,
        fleeChance = opts.fleeChance,
        mx = 0, my = 0,
    }, DeployPhase)
end

-- The plate's own rect, however tall the stack above it happens to stand.
local function fleeRect(p)
    for _, c in ipairs(p:controls()) do
        if c.key == "flee" then return c.rect end
    end
end

-- The same plate, by its geometry: controls() builds its rects fresh on every call, so the note's
-- answer is never the identical table the probe read -- it is the same RECT, which is the claim.
local function sameRect(a, b)
    return a and b and a.x == b.x and a.y == b.y and a.w == b.w and a.h == b.h
end

local function withMode(mode, touch, fn)
    local oldMode, oldTouch = InputMode.current, InputMode.touch
    InputMode.current, InputMode.touch = mode, touch
    local ok, err = pcall(fn)
    InputMode.current, InputMode.touch = oldMode, oldTouch
    assert(ok, err)
end

return {
    {
        name = "the note opens under the pointer that is on the plate",
        fn = function()
            local p = phase({ onFlee = function() end, fleeChance = 55 })
            local r = fleeRect(p)
            assert(r, "the plate itself is missing")
            withMode("mouse", false, function()
                p.mx, p.my = r.x + r.w / 2, r.y + r.h / 2
                assert(sameRect(p:fleeNotePlate(), r), "hovering the plate says nothing")
                p.mx, p.my = r.x + r.w / 2, r.y - 40
                assert(p:fleeNotePlate() == nil, "the note stands with the pointer off the plate")
            end)
        end,
    },
    {
        -- The half a pointer-only reading would have lost: a pad selection sits ON a plate and never
        -- hovers one, so a note gated on the cursor is a note a pad can never open.
        name = "a pad sitting on the plate opens it too",
        fn = function()
            local p = phase({ onFlee = function() end, fleeChance = 55 })
            local r = fleeRect(p)
            withMode("gamepad", false, function()
                p.focus = "flee"
                assert(sameRect(p:fleeNotePlate(), r), "the selection on the plate says nothing")
                p.focus = "begin"
                assert(p:fleeNotePlate() == nil, "the note follows the selection off the plate")
            end)
        end,
    },
    {
        -- A finger has no hover, and the last tap's coordinates are wherever the player last pressed.
        name = "a finger never opens it",
        fn = function()
            local p = phase({ onFlee = function() end, fleeChance = 55 })
            local r = fleeRect(p)
            withMode("mouse", true, function()
                p.mx, p.my = r.x + r.w / 2, r.y + r.h / 2
                assert(p:fleeNotePlate() == nil, "a tap on the plate left a box behind it")
            end)
        end,
    },
    {
        -- No plate, no note: a fight that may not be fled (an objective, a campaign board) never draws
        -- the button at all, and an explanation of a control that is not there is a lie about the board.
        name = "a fight with no way out has no note",
        fn = function()
            local p = phase()
            withMode("mouse", false, function()
                p.mx, p.my = p.column.x + 10, p.column.y + 10
                assert(p:fleeNotePlate() == nil, "a board with no escape explained one")
            end)
            withMode("gamepad", false, function()
                p.focus = "flee"
                assert(p:fleeNotePlate() == nil, "a stale selection opened a plate that is gone")
            end)
        end,
    },
    {
        -- Mid-placement the carried portrait is over the cursor. A box under it is in the way of the
        -- move rather than an answer to it.
        name = "a body in hand keeps it shut",
        fn = function()
            local p = phase({ onFlee = function() end, fleeChance = 55 })
            local r = fleeRect(p)
            withMode("mouse", false, function()
                p.mx, p.my = r.x + r.w / 2, r.y + r.h / 2
                p.drag = { active = true, char = {} }
                assert(p:fleeNotePlate() == nil, "the note opened under a dragged body")
                p.drag = nil
                p.held = {}
                assert(p:fleeNotePlate() == nil, "the note opened under a picked-up body")
            end)
        end,
    },
}
