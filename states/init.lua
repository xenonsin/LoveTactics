-- Simple state manager. A state is a table that may define any of the
-- LÖVE callbacks (load, update, draw, keypressed, mousepressed, ...).
-- Switching calls the new state's `enter` (if present).

local State = {
    current = nil,
}

local Scale = require("scale")

function State.switch(state, ...)
    State.current = state
    -- A screen only gets the handheld space if it has been laid out for one (see
    -- Scale.allowHandheldSpace). Set BEFORE enter, since a state lays itself out against
    -- Scale.WIDTH/HEIGHT on the way in, and re-fit immediately so it enters into the right shape.
    Scale.allowHandheldSpace = state.handheldSpace == true
    if love.graphics and Scale.windowW then
        Scale.resize(love.graphics.getDimensions())
    end
    if state.enter then state.enter(state, ...) end
end

return State
