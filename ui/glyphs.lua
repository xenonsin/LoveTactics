-- Tiny vector glyphs drawn inline beside a number, shared by any widget that needs one. Lifted out of
-- ui/combat_panel.lua once a second module wanted the hourglass: the same mark has to read the same
-- wherever a duration is quoted, and ui/item_tooltip.lua cannot reach into the panel for it without
-- inverting the dependency (the panel is what owns and positions the tooltip).
--
-- Each glyph fills the box it is handed and sets its own colour, so a caller lays out the box and the
-- glyph draws to it. Kin to ui/status_badge.lua, which shares a whole badge the same way.

local Glyphs = {}

-- Time: two triangles meeting at the waist. The game's mark for "this is measured in ticks" -- worn by
-- an ability's speed badge, the initiative read-out, a channel's resolve marker and an item's recovery.
function Glyphs.hourglass(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a or 1)
    love.graphics.polygon("fill", x, y, x + w, y, x + w / 2, y + h / 2)
    love.graphics.polygon("fill", x + w / 2, y + h / 2, x, y + h, x + w, y + h)
end

return Glyphs
