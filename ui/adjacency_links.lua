-- Adjacency connector wires for an item grid (Combat.adjacencyLinks), shared by the loadout grid
-- (ui/inventory_grid.lua) and the battle item panel (ui/combat_panel.lua) so both read the same.
--
-- A wire runs centre-to-centre between two neighboring cells, drawn ON the slot plates but UNDER
-- everything the cards say: the host lays down its plates, calls this, then draws icons, badges,
-- name bands and borders over the top. So a wire reads clearly across the plate and the gap, and
-- still never obscures an icon or a word. Each end is anchored with a dot at the slot centre,
-- which the icon then covers.
--
--   -- after the slot plates, before the item contents:
--   AdjacencyLinks.draw(char, function(i) return self:slotRect(i) end, { width = 3 })
--
-- Tint legends with AdjacencyLinks.COLOR so they can't drift from the wires.

local Combat = require("models.combat")

local AdjacencyLinks = {}

-- Wire tint per adjacency relationship kind (see Combat.adjacencyLinks).
AdjacencyLinks.COLOR = {
    aura        = { 0.95, 0.55, 0.28 }, -- ember orange (an aura infusing a neighbor)
    boost       = { 0.55, 0.78, 1.00 }, -- steel blue (an ability scaling off a neighbor)
    requirement = { 0.70, 0.88, 0.45 }, -- green (a requirement satisfied by a neighbor)
}

local FALLBACK = { 0.8, 0.8, 0.8 }

-- `slotRect(index)` returns the x, y, w, h of a 1-based cell, matching the host widget's grid math.
function AdjacencyLinks.draw(char, slotRect, opts)
    if not char then return end
    opts = opts or {}
    local alpha = opts.alpha or 1
    local width = opts.width or 3

    local function centre(index)
        local x, y, w, h = slotRect(index)
        return x + w / 2, y + h / 2
    end

    love.graphics.setLineWidth(width)
    for _, link in ipairs(Combat.adjacencyLinks(char)) do
        local c = AdjacencyLinks.COLOR[link.kind] or FALLBACK
        local ax, ay = centre(link.from)
        local bx, by = centre(link.to)
        love.graphics.setColor(c[1], c[2], c[3], alpha)
        love.graphics.line(ax, ay, bx, by)
        love.graphics.circle("fill", ax, ay, width)
        love.graphics.circle("fill", bx, by, width)
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1)
end

return AdjacencyLinks
