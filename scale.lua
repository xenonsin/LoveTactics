-- Virtual-resolution letterbox scaling.
--
-- The whole game is authored in a fixed logical resolution (WIDTH x HEIGHT,
-- 16:9). Every frame is drawn through a transform that scales that logical
-- space up to fit the real window, centered, with black bars on any leftover
-- axis (letterbox / pillarbox). Because the design space is 16:9, a 16:9 window
-- (720p, 1080p, 1440p, ...) fills edge to edge with no bars; bars only appear
-- if the window is resized to a non-16:9 shape.
--
-- Mouse input is converted back to logical coordinates with Scale.toGame, so
-- every widget keeps hit-testing in the same coordinates it draws in.
--
--   -- love.draw:
--   Scale.start(); state:draw(); Scale.finish()
--   -- love.load / love.resize:
--   Scale.resize(love.graphics.getDimensions())
--   -- mouse callbacks:
--   local gx, gy = Scale.toGame(x, y)
--
-- ONE SET OF UNITS. Everything here -- the fit, the offsets, the scissor, the canvas, the pointer
-- conversion -- is in the WINDOW's own coordinates, which is also what love.graphics draws in and
-- what mouse callbacks report. The real pixel count underneath can be larger: conf.lua asks for a
-- high-DPI drawable, so on a phone browser (and a retina panel) one window unit is three device
-- pixels. That density belongs to the RASTERISER, not to the layout -- LOVE applies it to every
-- draw on its own, ui/theme.lua bakes glyph atlases against it, and the canvas below carries it --
-- so nothing in this file, or above it, ever has to see a pixel. Mixing the two is what drew the
-- frame three times too large and off the side of the screen.
--
-- A window taller than it is wide is fitted turned a quarter turn clockwise, so a phone held
-- upright still plays the game full-screen. See Scale.rotated.
--
-- The frame is composited into a canvas sized to the REAL WINDOW (not the 1280x720 logical
-- space): Scale.start binds it and applies the letterbox translate+scale up front, so every
-- image, shape and glyph rasterises at native display resolution, and Scale.finish blits the
-- canvas 1:1 to the window. That is the whole point of the canvas -- drawing the logical space
-- straight into a 720p target and upscaling the flattened result is what made full-screen soft;
-- transforming first, rasterising at native res, keeps it crisp at any window size. (Bitmap fonts
-- are the one partial exception -- baked at their point size, then transform-scaled -- but they
-- sharpen too, and everything else is exact.)
--
-- Because the whole frame lands in that canvas, the blit is also the natural seam for full-screen
-- POST-PROCESSING: the canvas is drawn through shaders/screen.lua (vignette, desat, punch, flash)
-- and offset by a screen shake, both driven by ui/screen_fx.lua. All of it is guarded -- a driver
-- that refuses the canvas or the shader latches back to the plain translate/scale/scissor path
-- forever, and the game plays on exactly as it did before.
--
-- This file must not touch love.graphics at require-time so it loads under the
-- headless test suite (see CLAUDE.md). The canvas and shader are built lazily on the
-- first Scale.start, which never runs headlessly.

local ScreenFx = require("ui.screen_fx")
local ScreenShader = require("shaders.screen")

local Scale = {}

-- Ceiling on the overscale the canvas blit may use to hide the letterbox seam behind a screen
-- shake. It is a CEILING, not a constant: a still frame blits at exactly 1.0 so nothing at the
-- edge of the logical space is ever cropped, and only a live shake grows it (see shakeOverscale).
local SHAKE_OVERSCALE_MAX = 1.06

-- Logical design resolution. Author every screen and every data-defined rect in
-- this space; the rest of the codebase reads Scale.WIDTH / Scale.HEIGHT rather
-- than love.graphics.getWidth/Height so it stays resolution-independent.
Scale.WIDTH = 1280
Scale.HEIGHT = 720

-- WHICH LAYOUT THE SCREEN IS BIG ENOUGH FOR.
--
-- A glyph's cap height subtends roughly `1.12 * size * Scale.scale` arcminutes, and about 12 of
-- those is the floor for a glance (see ui/theme.lua's Theme.MIN_BODY for the whole derivation). With
-- the body floor at 14 that puts the break-even at a fit of 0.77 -- so the desktop arrangement holds
-- down to a 1024x576 window and a handheld one takes over below it.
--
-- The fit is a good instrument in a BROWSER, because a CSS pixel is defined as an angular unit: it
-- subtends about the same 1.6' on a phone at arm's length as on a monitor at desk distance, which is
-- why one threshold serves a handset and a shrunken window alike. It is a bad instrument on a native
-- handheld -- a Switch is 1280x720 at fit 1.0, indistinguishable from a desktop by this test, while
-- its pixels subtend 0.92' against a CSS pixel's 1.6'. So a native handheld has to SAY SO, which is
-- what forceHandheld is for; main.lua sets it from the same signal that arms the quarter turn.
Scale.HANDHELD_ENTER = 0.80 -- drop to the handheld arrangement below this fit...
Scale.HANDHELD_EXIT  = 0.90 -- ...and only climb back out above this one
Scale.forceHandheld = false -- a screen that knows it is small however the arithmetic reads
Scale.handheld = false      -- the live answer, recomputed every resize

-- Measure a window against the DESKTOP space, never against the live one. Switching arrangements
-- changes Scale.WIDTH/HEIGHT, which would change this fit, which would switch the arrangement back:
-- a loop that oscillates every frame. The desktop space is the fixed yardstick that breaks it.
--
-- Long axis against 1280, short against 720, so a screen held either way up gives the same answer as
-- the quarter-turned frame it is about to draw.
function Scale.layoutFit(windowW, windowH)
    if not (windowW and windowH and windowW > 0 and windowH > 0) then return 1 end
    return math.min(math.max(windowW, windowH) / 1280, math.min(windowW, windowH) / 720)
end

-- The predicate, with a deadband: a window dragged across the boundary must not re-lay the whole
-- screen on every frame of the drag, so leaving costs more than entering did.
function Scale.wantsHandheld(windowW, windowH)
    if Scale.forceHandheld then return true end
    local fit = Scale.layoutFit(windowW, windowH)
    if Scale.handheld then return fit < Scale.HANDHELD_EXIT end
    return fit < Scale.HANDHELD_ENTER
end

Scale.scale = 1
Scale.offsetX = 0
Scale.offsetY = 0

-- A drawable taller than it is wide -- a phone held upright in a browser -- is fitted with the
-- logical space turned a QUARTER TURN CLOCKWISE rather than pillarboxed into a strip across the
-- middle. The game's top edge then runs down the right-hand side of the screen, so the player
-- turns the device anticlockwise to read it, and the whole screen is used either way up.
--
-- Nothing above this file knows: every draw goes through Scale.start and every pointer position
-- through Scale.toGame, so the rotation lives entirely in the two of them and their inverse.
-- ...where the screen is a thing the player holds. A desktop window dragged into a tall shape is
-- pillarboxed as it always was, since a monitor does not turn: main.lua sets this on the browser
-- and mobile builds only.
Scale.allowRotate = false
Scale.rotated = false

-- The fitted rect on screen, in window units -- the logical space's own width and height when
-- upright, swapped when it is turned.
function Scale.fittedW() return (Scale.rotated and Scale.HEIGHT or Scale.WIDTH) * Scale.scale end
function Scale.fittedH() return (Scale.rotated and Scale.WIDTH or Scale.HEIGHT) * Scale.scale end

-- Recompute the fit for a given WINDOW size (love.graphics.getDimensions, the units mouse
-- callbacks report). Call on load and on resize.
function Scale.resize(windowW, windowH)
    local rotated = Scale.allowRotate and windowH > windowW
    local s
    if rotated then
        s = math.min(windowH / Scale.WIDTH, windowW / Scale.HEIGHT)
    else
        s = math.min(windowW / Scale.WIDTH, windowH / Scale.HEIGHT)
    end
    Scale.rotated = rotated
    Scale.scale = s
    Scale.offsetX = math.floor((windowW - (rotated and Scale.HEIGHT or Scale.WIDTH) * s) / 2)
    Scale.offsetY = math.floor((windowH - (rotated and Scale.WIDTH or Scale.HEIGHT) * s) / 2)
    Scale.windowW = windowW
    Scale.windowH = windowH
    -- Answered on every resize, and read by whoever lays out. Deliberately does NOT switch
    -- Scale.WIDTH/HEIGHT yet: only one arrangement is registered, so the rule is a no-op that
    -- reports -- which is exactly how it wants to ship, since it can then be exercised on its own by
    -- dragging a window across 1024x576 before anything depends on the answer.
    Scale.handheld = Scale.wantsHandheld(windowW, windowH)
    -- The canvas is sized to the real window, so a resize retires it; ensureCanvas rebuilds it at
    -- the new size on the next frame. (noCanvas stays latched -- a driver that failed once still
    -- gets the fallback path.) Release the old target rather than leaning on the GC, since dragging
    -- a resizable edge fires resize every frame.
    if Scale.canvas and (Scale.canvasW ~= windowW or Scale.canvasH ~= windowH) then
        pcall(function() Scale.canvas:release() end)
        Scale.canvas = nil
    end
end

-- Build the logical-space canvas and the post shader, once, guarded. A failure latches `noCanvas`:
-- the frame is drawn straight to the window through the old transform for the rest of the session,
-- exactly the tolerance ui/field_fx.lua gives a shader it cannot compile. Returns the canvas or nil.
function Scale.ensureCanvas()
    if Scale.canvas then return Scale.canvas end
    if Scale.noCanvas then return nil end
    local w = Scale.windowW or love.graphics.getWidth()
    local h = Scale.windowH or love.graphics.getHeight()
    -- w and h are WINDOW units, so the canvas takes the display's density explicitly: it is
    -- addressed as w x h, exactly like the window it stands in for, and carries w*dpi by h*dpi real
    -- texels underneath. That is what keeps the game rasterising at the screen's own resolution
    -- instead of a third of it. Passing 1 here would throw that resolution away while leaving every
    -- coordinate in this file looking correct, which is the silent version of this bug.
    local okDpi, dpi = pcall(love.graphics.getDPIScale)
    if not (okDpi and type(dpi) == "number" and dpi > 0) then dpi = 1 end
    local okC, canvas = pcall(love.graphics.newCanvas, w, h, { dpiscale = dpi })
    if not okC or not canvas then
        Scale.noCanvas = true
        return nil
    end
    Scale.canvas = canvas
    Scale.canvasW = w
    Scale.canvasH = h
    -- The canvas is window-sized, so a still frame blits it 1:1 -- point sampling is exact. Scale.finish
    -- switches this to linear only for the frames a shake overscales the canvas past a whole pixel.
    canvas:setFilter("nearest", "nearest")
    Scale.canvasFilter = "nearest"
    -- The shader is optional on top of the canvas: if it will not compile we keep the canvas (so shake
    -- still works) and simply blit without post terms.
    local okS, shader = pcall(love.graphics.newShader, ScreenShader.source)
    Scale.screenShader = (okS and shader) or nil
    return canvas
end

-- Begin drawing in logical space. With the canvas, the letterbox translate+scale is applied UP FRONT
-- (into the window-sized canvas), so the logical space rasterises at native display resolution; the
-- scissor clips to the logical rect so nothing bleeds into the bars. Without the canvas, fall back to
-- blacking the window and applying the same translate/scale/scissor directly, exactly as before.
--
-- The transform is a quarter turn clockwise on a portrait drawable: the logical origin lands at
-- the top-RIGHT of the fitted rect and the logical x axis runs down the screen. Scale.toGame is
-- the exact inverse, so a widget is clicked where it is seen.
local function applyFit()
    love.graphics.push()
    if Scale.rotated then
        love.graphics.translate(Scale.offsetX + Scale.HEIGHT * Scale.scale, Scale.offsetY)
        love.graphics.rotate(math.pi / 2)
    else
        love.graphics.translate(Scale.offsetX, Scale.offsetY)
    end
    love.graphics.scale(Scale.scale, Scale.scale)
    -- The scissor is in screen pixels, untouched by the transform above, so it takes the fitted
    -- rect as it lies on the drawable -- turned on its side when the frame is.
    love.graphics.setScissor(Scale.offsetX, Scale.offsetY, Scale.fittedW(), Scale.fittedH())
end

function Scale.start()
    -- The drawable can change size without a resize event ever reaching us -- a browser canvas does
    -- exactly that -- and a stale fit draws the whole frame into one corner of the buffer. Two
    -- integers a frame is the cheapest insurance there is.
    local okD, ww, wh = pcall(love.graphics.getDimensions)
    if okD and ww and ww > 0 and (ww ~= Scale.windowW or wh ~= Scale.windowH) then
        Scale.resize(ww, wh)
    end

    local canvas = Scale.ensureCanvas()
    if canvas then
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 1)
        applyFit()
        Scale.usingCanvas = true
    else
        Scale.usingCanvas = false
        love.graphics.clear(0, 0, 0, 1)
        applyFit()
    end
end

-- Configure the post shader from ui/screen_fx.lua's current amounts. Sent every active blit rather than
-- cached, since these change every frame a fight is loud.
local function sendPost(shader, post)
    -- uTexel drives the blur tap distance. The canvas is now native-res, so a real-pixel texel
    -- (1/canvasW) would shrink the blur's logical radius at high resolutions; multiply by the letterbox
    -- scale so uBlur keeps meaning "logical pixels" exactly as it did on the old 1280x720 canvas.
    shader:send("uTexel", { Scale.scale / Scale.canvasW, Scale.scale / Scale.canvasH })
    shader:send("uPunch", post.punch)
    shader:send("uBlur", post.blur)
    shader:send("uDesat", post.desat)
    shader:send("uVignette", post.vignette)
    shader:send("uVignetteColor", post.vignetteColor)
    shader:send("uFlash", post.flash)
    shader:send("uFlashColor", post.flashColor)
end

-- How much bigger than the letterbox fit this frame's blit has to be for a shake of (sx, sy) real
-- pixels to stay covered: enough that half the surplus width/height exceeds the offset. A still frame
-- (no shake) wants none of it and gets exactly 1 -- anything more would crop the edges of the logical
-- space permanently and resample a 1:1 window into mush.
local function shakeOverscale(sx, sy)
    if sx == 0 and sy == 0 then return 1 end
    local need = math.max(
        1 + 2 * math.abs(sx) / Scale.canvasW,
        1 + 2 * math.abs(sy) / Scale.canvasH)
    return math.min(need, SHAKE_OVERSCALE_MAX)
end

-- Point sampling for a blit that lands on exact pixels, linear for one that does not. Set on the
-- canvas rather than globally so nothing else in the frame is affected.
local function setFilter(want)
    if Scale.canvasFilter == want then return end
    Scale.canvas:setFilter(want, want)
    Scale.canvasFilter = want
end

function Scale.finish()
    if not Scale.usingCanvas then
        love.graphics.setScissor()
        love.graphics.pop()
        return
    end

    -- Drop the logical-space scissor and transform, unbind the canvas, and blit it to the window. The
    -- canvas is already window-sized (the letterbox is baked into its contents), so a still frame draws
    -- it 1:1 at the origin. A shake offsets it by (sx, sy) real pixels and overscales it just enough to
    -- keep the moved edges covered. The window is cleared black first so the bars stay clean.
    love.graphics.setScissor()
    love.graphics.pop()
    love.graphics.setCanvas()
    love.graphics.clear(0, 0, 0, 1)

    local sx, sy = ScreenFx.shakeOffset()
    local over = shakeOverscale(sx, sy)
    -- Centre the overscaled canvas over the window, then add the shake.
    local dx = -(Scale.canvasW * (over - 1)) / 2 + sx
    local dy = -(Scale.canvasH * (over - 1)) / 2 + sy

    -- A still frame lands the canvas 1:1 on the window -> point sampling is lossless; a shake resamples
    -- it (non-integer overscale), so smooth that.
    if over == 1 and sx == 0 and sy == 0 then
        setFilter("nearest")
    else
        setFilter("linear")
    end

    local post = ScreenFx.post()
    love.graphics.setColor(1, 1, 1, 1)
    if post.active and Scale.screenShader then
        love.graphics.setShader(Scale.screenShader)
        sendPost(Scale.screenShader, post)
        love.graphics.draw(Scale.canvas, dx, dy, 0, over, over)
        love.graphics.setShader()
    else
        love.graphics.draw(Scale.canvas, dx, dy, 0, over, over)
    end
end

-- Convert real window coordinates (e.g. from mouse callbacks) to logical
-- coordinates. Points inside the letterbox bars map outside [0,WIDTH]x[0,HEIGHT].
--
-- Exactly the inverse of the fit applied in applyFit -- including the quarter turn, which swaps the
-- axes and runs the logical y back from the right-hand edge. A pointer arrives in window units and
-- the fit is computed in window units, so there is nothing to reconcile first.
function Scale.toGame(x, y)
    if Scale.rotated then
        return (y - Scale.offsetY) / Scale.scale,
               (Scale.offsetX + Scale.HEIGHT * Scale.scale - x) / Scale.scale
    end
    return (x - Scale.offsetX) / Scale.scale,
           (y - Scale.offsetY) / Scale.scale
end

-- The same conversion for a MOVEMENT rather than a position: no offsets, and the turn is a plain
-- axis swap. (A drag of dx across a turned screen is a drag of dx DOWN the logical space.)
function Scale.toGameDelta(dx, dy)
    if Scale.rotated then
        return dy / Scale.scale, -dx / Scale.scale
    end
    return dx / Scale.scale, dy / Scale.scale
end

return Scale
