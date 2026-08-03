-- A horizontal progress bar for filling toward a THRESHOLD -- distinct from the resource bars scattered
-- through the battle UI, which show a pool draining. Those answer "how much is left?"; this answers
-- "how close am I?", and the difference shows in what it draws: a `gain` segment lighting the slice
-- that just landed, and a distinct FULL state for a bar with nothing left to fill toward.
--
--   ProgressBar.draw(x, y, w, h, value, span, {
--       gain  = 1,                 -- of `value`, how much arrived just now (lit brighter)
--       color = Theme.accentAmber, -- the fill (defaults to the spotlight gold)
--       full  = false,             -- draw the "maxed, nothing to fill toward" state instead
--   })
--
-- Not a widget with state or input: it draws and returns. Anything that needs the fill to animate owns
-- its own eased `value` and hands it in, which keeps the easing where the meaning is (see
-- ui/panels/advancement.lua, whose bar rolls over between levels).

local Theme = require("ui.theme")

local ProgressBar = {}

local RADIUS = 3

-- `value`/`span` are in whatever unit the caller thinks in (prestige, casts, quests) -- never a 0..1
-- ratio, so a caller cannot get the division wrong in its own way. `span` <= 0 draws an empty track.
function ProgressBar.draw(x, y, w, h, value, span, opts)
    opts = opts or {}
    local alpha = opts.alpha or 1
    local color = opts.color or Theme.accentAmber

    Theme.set(Theme.barTrack, 0.9 * alpha)
    love.graphics.rectangle("fill", x, y, w, h, RADIUS, RADIUS)

    if opts.full then
        -- A capped bar is filled flat and dimmed rather than left sitting at 99%: a bar that can never
        -- complete but looks nearly complete reads as a broken bar, not as an achievement.
        love.graphics.setColor(color[1] * 0.55, color[2] * 0.55, color[3] * 0.55, 0.85 * alpha)
        love.graphics.rectangle("fill", x, y, w, h, RADIUS, RADIUS)
    elseif span and span > 0 then
        local ratio = math.max(0, math.min(1, (value or 0) / span))
        local gain = math.max(0, math.min(value or 0, opts.gain or 0))
        local settled = math.max(0, math.min(1, ((value or 0) - gain) / span))

        -- What was already banked, then the slice that just arrived on top of it -- so the eye lands on
        -- the change rather than on the total.
        love.graphics.setColor(color[1] * 0.7, color[2] * 0.7, color[3] * 0.7, 0.95 * alpha)
        love.graphics.rectangle("fill", x, y, w * settled, h, RADIUS, RADIUS)
        if ratio > settled then
            love.graphics.setColor(color[1], color[2], color[3], 0.95 * alpha)
            love.graphics.rectangle("fill", x + w * settled, y, w * (ratio - settled), h, RADIUS, RADIUS)
        end
    end

    Theme.set(Theme.barOutline, (Theme.barOutline[4] or 1) * alpha)
    love.graphics.rectangle("line", x, y, w, h, RADIUS, RADIUS)
    love.graphics.setColor(1, 1, 1)
end

return ProgressBar
