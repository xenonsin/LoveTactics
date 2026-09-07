-- Tests for scale.lua's fit -- the letterbox, and the QUARTER TURN a handset held upright gets.
--
-- The turn shipped as dead code: scale.lua declared `Scale.allowRotate`, its header and the web
-- shell's header both said main.lua switched it on for a handset, and main.lua had never heard of
-- it. Nothing was wrong with the arithmetic; nothing ever reached it. So this file pins both halves
-- -- the maths here, and the two lines of wiring that feed it by reading the source that carries
-- them, since a flag set during love.load cannot be observed from a headless spec.
--
-- The invariant that matters is that toGame is the EXACT inverse of the transform applyFit lays
-- down, turned or not: a widget has to be clicked where it is seen.

local Scale = require("scale")

-- Where applyFit puts a logical point, worked forward by hand: translate(offsetX + HEIGHT*s,
-- offsetY) then rotate(pi/2) when turned, a plain translate when not. This is the drawing side of
-- the pair, written out independently so a change to one has to be a change to both.
local function toScreen(lx, ly)
    if Scale.rotated then
        return Scale.offsetX + Scale.HEIGHT * Scale.scale - ly * Scale.scale,
               Scale.offsetY + lx * Scale.scale
    end
    return Scale.offsetX + lx * Scale.scale, Scale.offsetY + ly * Scale.scale
end

local function near(a, b, why)
    assert(math.abs(a - b) <= 1.001, (why or "") .. ": " .. tostring(a) .. " vs " .. tostring(b))
end

-- Every case leaves the flag as it found it; the game's own default is off.
local function withRotate(allow, fn)
    local was = Scale.allowRotate
    Scale.allowRotate = allow
    local ok, err = pcall(fn)
    Scale.allowRotate = was
    assert(ok, err)
end

return {
    {
        name = "a 16:9 drawable fills edge to edge with no bars",
        fn = function()
            Scale.resize(1920, 1080)
            assert(not Scale.rotated, "a landscape drawable is never turned")
            near(Scale.scale, 1.5, "scale")
            near(Scale.offsetX, 0, "offsetX")
            near(Scale.offsetY, 0, "offsetY")
        end,
    },
    {
        name = "a wider-than-16:9 drawable pillarboxes, a taller one letterboxes",
        fn = function()
            Scale.resize(2560, 1080) -- ultrawide: bars left and right
            near(Scale.scale, 1080 / 720, "scale fits the short axis")
            assert(Scale.offsetX > 0 and Scale.offsetY == 0, "bars on the wrong axis")

            Scale.resize(1280, 1000) -- squarer: bars top and bottom
            near(Scale.scale, 1, "scale fits the short axis")
            assert(Scale.offsetY > 0 and Scale.offsetX == 0, "bars on the wrong axis")
        end,
    },
    {
        -- A monitor does not turn. A desktop window dragged into a tall shape is pillarboxed as it
        -- always was -- which is why the turn is opt-in rather than a property of the shape alone.
        name = "a portrait drawable is NOT turned unless the screen is one the player can turn",
        fn = function()
            withRotate(false, function()
                Scale.resize(720, 1280)
                assert(not Scale.rotated, "a desktop window went sideways")
                near(Scale.scale, 720 / 1280, "scale fits the width")
                assert(Scale.offsetY > 0, "expected bars above and below")
            end)
        end,
    },
    {
        name = "a handset held upright turns the picture and uses the whole screen",
        fn = function()
            withRotate(true, function()
                Scale.resize(720, 1280)
                assert(Scale.rotated, "a portrait handset was left pillarboxed")
                -- Turned, the logical WIDTH runs down the screen: the fit is the smaller of the
                -- two axes measured against the swapped pair, and 720x1280 is exactly 16:9 turned,
                -- so it lands edge to edge with no bars at all.
                near(Scale.scale, 1, "scale")
                near(Scale.offsetX, 0, "offsetX")
                near(Scale.offsetY, 0, "offsetY")
                near(Scale.fittedW(), 720, "fitted width is the logical HEIGHT")
                near(Scale.fittedH(), 1280, "fitted height is the logical WIDTH")
            end)
        end,
    },
    {
        name = "the turned fit stays inside the drawable",
        fn = function()
            withRotate(true, function()
                Scale.resize(828, 1792) -- a taller handset: bars on the long axis
                assert(Scale.rotated, "expected the turn")
                assert(Scale.offsetX >= 0 and Scale.offsetY >= 0, "the fit hangs off the drawable")
                assert(Scale.offsetX * 2 + Scale.fittedW() <= 828 + 1, "wider than the drawable")
                assert(Scale.offsetY * 2 + Scale.fittedH() <= 1792 + 1, "taller than the drawable")
            end)
        end,
    },
    {
        -- The one that matters: a widget is clicked where it is seen. Corners and centre, both ways
        -- up, driven through the forward transform and back out of toGame.
        name = "toGame inverts the fit exactly, turned or not",
        fn = function()
            local points = { { 0, 0 }, { 1280, 0 }, { 0, 720 }, { 1280, 720 }, { 640, 360 }, { 17, 511 } }
            local function roundTrip(w, h)
                Scale.resize(w, h)
                for _, p in ipairs(points) do
                    local sx, sy = toScreen(p[1], p[2])
                    local lx, ly = Scale.toGame(sx, sy)
                    near(lx, p[1], "x round-trip at " .. w .. "x" .. h)
                    near(ly, p[2], "y round-trip at " .. w .. "x" .. h)
                end
            end
            withRotate(false, function() roundTrip(1920, 1080) roundTrip(1280, 1000) end)
            withRotate(true, function() roundTrip(720, 1280) roundTrip(828, 1792) end)
        end,
    },
    {
        -- A drag ACROSS the glass of a turned screen is a drag DOWN the logical space. Deltas carry
        -- no offset, so the turn is a plain axis swap with one sign on it.
        name = "toGameDelta swaps the axes on a turned screen",
        fn = function()
            withRotate(true, function()
                Scale.resize(720, 1280) -- scale 1, so a delta is its own logical size
                local dx, dy = Scale.toGameDelta(10, 0)
                near(dx, 0, "a drag across the glass moves nothing along logical x")
                near(dy, -10, "a drag right is a drag UP the logical space")
                dx, dy = Scale.toGameDelta(0, 10)
                near(dx, 10, "a drag down the glass is a drag along logical x")
                near(dy, 0, "and nothing along logical y")
            end)
            withRotate(false, function()
                Scale.resize(2560, 1440) -- scale 2
                local dx, dy = Scale.toGameDelta(10, 20)
                near(dx, 5, "an untuned delta is just divided by the scale")
                near(dy, 10, "an untuned delta is just divided by the scale")
            end)
        end,
    },
    {
        -- The half that was missing. `Scale.allowRotate` is set during love.load, which a headless
        -- spec cannot run, so the wiring is read off the source instead -- exactly the check whose
        -- absence let a documented feature ship switched off.
        name = "main.lua switches the turn on for a handset",
        fn = function()
            local src = assert(love.filesystem.read("main.lua"), "main.lua is readable")
            assert(src:find("Scale.allowRotate%s*=%s*true"),
                "nothing in main.lua turns Scale.allowRotate on -- scale.lua's quarter turn is dead code")
            assert(src:find("\"mobile\""),
                "main.lua does not look for the `mobile` argument the web shell passes on a touchscreen")
            assert(src:find("\"iOS\"") and src:find("\"Android\""),
                "a native handset build has no way to ask for the turn")
        end,
    },
    {
        -- The other end of the same wire: the page has to send what main.lua looks for, and it has
        -- to hand a portrait handset a portrait canvas -- a CSS box locked to 16:9 would leave the
        -- drawable landscape and there would be nothing to turn.
        name = "the web shell passes `mobile` on a coarse pointer and gives it the whole viewport",
        fn = function()
            local src = assert(love.filesystem.read("tools/web/index.html"), "the web shell is readable")
            assert(src:find("pointer: coarse", 1, true), "the shell does not ask whether the pointer is a finger")
            assert(src:find("'mobile'", 1, true) or src:find('"mobile"', 1, true),
                "the shell never passes the `mobile` argument main.lua reads")
            assert(src:find("#canvas%s*{%s*width:%s*100%%;%s*height:%s*100%%;%s*}"),
                "the coarse-pointer rule no longer hands the canvas the whole viewport, so the "
                .. "drawable stays landscape and the turn can never fire")
        end,
    },
}
