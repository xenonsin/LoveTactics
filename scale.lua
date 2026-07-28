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

Scale.scale = 1
Scale.offsetX = 0
Scale.offsetY = 0

-- Recompute the fit for a given real window size. Call on load and on resize.
function Scale.resize(windowW, windowH)
    local s = math.min(windowW / Scale.WIDTH, windowH / Scale.HEIGHT)
    Scale.scale = s
    Scale.offsetX = math.floor((windowW - Scale.WIDTH * s) / 2)
    Scale.offsetY = math.floor((windowH - Scale.HEIGHT * s) / 2)
    Scale.windowW = windowW
    Scale.windowH = windowH
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
    local okC, canvas = pcall(love.graphics.newCanvas, w, h)
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
function Scale.start()
    local canvas = Scale.ensureCanvas()
    if canvas then
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 1)
        love.graphics.push()
        love.graphics.translate(Scale.offsetX, Scale.offsetY)
        love.graphics.scale(Scale.scale, Scale.scale)
        love.graphics.setScissor(Scale.offsetX, Scale.offsetY,
            Scale.WIDTH * Scale.scale, Scale.HEIGHT * Scale.scale)
        Scale.usingCanvas = true
    else
        Scale.usingCanvas = false
        love.graphics.clear(0, 0, 0, 1)
        love.graphics.push()
        love.graphics.translate(Scale.offsetX, Scale.offsetY)
        love.graphics.scale(Scale.scale, Scale.scale)
        love.graphics.setScissor(Scale.offsetX, Scale.offsetY,
            Scale.WIDTH * Scale.scale, Scale.HEIGHT * Scale.scale)
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
function Scale.toGame(x, y)
    return (x - Scale.offsetX) / Scale.scale,
           (y - Scale.offsetY) / Scale.scale
end

return Scale
