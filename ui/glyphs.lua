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

-- The resource glyphs: one shape per pool. Born as cost-badge marks in ui/combat_panel.lua, where a
-- badge's resource tint is spent the moment the actor can't afford the cast -- every short badge goes
-- WARN red at once -- so the SHAPE has to carry which pool is short on its own. They moved here once
-- the pool bars and the tile tooltip wanted the same three marks beside their HP/MP/SP labels: a pool
-- has to read as the same shape wherever it's quoted, the way the hourglass does for ticks.

-- Mana: a cut gem, point up and point down. The arcane pool, and the oldest of the three marks.
function Glyphs.manaGem(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a or 1)
    local cx, cy, rx, ry = x + w / 2, y + h / 2, w / 2, h / 2
    love.graphics.polygon("fill", cx, cy - ry, cx + rx, cy, cx, cy + ry, cx - rx, cy)
end

-- Stamina: a drop of sweat -- a round body under a point. Exertion, the bodily counterpart to the
-- gem's arcane. A bolt is the usual mark for this pool elsewhere, but not here: combat_panel's
-- drawBrokenLink is two diagonal strokes drawn red, and it stacks on the same slot right under this
-- badge, so a red bolt beside it would be a coin flip. The body is a circle rather than a polygon
-- because the drop's whole read is that its bottom is round where the gem's is sharp.
function Glyphs.staminaDrop(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a or 1)
    local cx, rr = x + w / 2, w * 0.42
    local by = y + h - rr
    love.graphics.polygon("fill", cx, y, cx + rr, by, cx - rr, by)
    love.graphics.circle("fill", cx, by, rr)
end

-- Health: a heart, the universal mark, which is what frees the drop above to read as sweat rather
-- than blood. Two lobes over a point: the lobed TOP is what tells it from the drop's single point
-- once both are forced red and the tint stops helping.
-- A heart is about as wide as it is tall, so it's drawn into a squared-off box centred in whatever
-- box the caller hands it: stretched to a tall slot the lobes thin out and the point draws long, and
-- the whole mark reads as a Y. The lobes are wide enough to merge into one round top for the same
-- reason -- two separate dots over a stem is the failure this shape has at 7px.
function Glyphs.healthHeart(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a or 1)
    local bh = math.min(h, w * 1.05)
    local top = y + (h - bh) / 2
    local rr = w * 0.30
    local cx, ly = x + w / 2, top + rr * 0.92
    love.graphics.circle("fill", cx - rr * 0.86, ly, rr)
    love.graphics.circle("fill", cx + rr * 0.86, ly, rr)
    love.graphics.polygon("fill", cx - w / 2, ly, cx + w / 2, ly, cx, top + bh)
end

-- Which glyph marks which pool. Callers that price an arbitrary stat (a mod's own pool) fall back to
-- the gem, the generic "some resource" shape.
Glyphs.RESOURCE = {
    mana    = Glyphs.manaGem,
    stamina = Glyphs.staminaDrop,
    health  = Glyphs.healthHeart,
}

return Glyphs
