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
-- This file must not touch love.graphics at require-time so it loads under the
-- headless test suite (see CLAUDE.md).

local Scale = {}

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
end

-- Begin drawing in logical space: black out the whole window (clean bars), then
-- translate + scale + clip to the logical area so nothing bleeds into the bars.
function Scale.start()
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.push()
    love.graphics.translate(Scale.offsetX, Scale.offsetY)
    love.graphics.scale(Scale.scale, Scale.scale)
    love.graphics.setScissor(Scale.offsetX, Scale.offsetY,
        Scale.WIDTH * Scale.scale, Scale.HEIGHT * Scale.scale)
end

function Scale.finish()
    love.graphics.setScissor()
    love.graphics.pop()
end

-- Convert real window coordinates (e.g. from mouse callbacks) to logical
-- coordinates. Points inside the letterbox bars map outside [0,WIDTH]x[0,HEIGHT].
function Scale.toGame(x, y)
    return (x - Scale.offsetX) / Scale.scale,
           (y - Scale.offsetY) / Scale.scale
end

return Scale
