-- Simple state manager. A state is a table that may define any of the
-- LÖVE callbacks (load, update, draw, keypressed, mousepressed, ...).
-- Switching calls the new state's `enter` (if present).

local State = {
    current = nil,
}

function State.switch(state, ...)
    State.current = state
    if state.enter then state.enter(state, ...) end
end

return State
