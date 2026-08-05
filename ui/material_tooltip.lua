-- The material tooltip: what a lump of forging stock is, and -- the part the player actually needs --
-- WHERE MORE OF IT COMES FROM.
--
--   MaterialTooltip.draw("material_ember_slag", mx, my, maxRight, player)
--
-- The Forge's bill can say "2 Ember Slag" and colour it red, which tells the player they are short and
-- nothing about what to do next. Both material families drop from the same place -- caches on the dead
-- ends of an overworld map (models/overworld.lua's Overworld:placeCaches) -- but they are chosen on
-- two completely different axes, and that difference IS the instruction:
--
--   CRAFT STOCK   grade and payout scale with how far the cache sits off the critical path. Short of
--                 it? Take the long way round on any quest at all.
--   HOUSE STOCK   which house's stock a cache pays is the SPONSOR of the quest being run. Short of it?
--                 Go and run that house's line -- and note that running it stocks somebody else's
--                 bench, which is the loop the seven sealed ladders are tied together with.
--
-- Follows ui/item_tooltip.lua's shape: measure() to lay it out, paint() to pin it at a spot the caller
-- chose, draw() for the ordinary "near the cursor, flipped and clamped" case.

local Material = require("models.material")
local Player = require("models.player")
local Theme = require("ui.theme")
local Vendor = require("models.vendor")
local Scale = require("scale")

local MaterialTooltip = {}

MaterialTooltip.WIDTH = 254
local PAD = 9

local function fonts()
    return Theme.display(15), Theme.body(12), Theme.body(11)
end

-- The house that spends this stock, as a display name -- nil for craft stock. Asks Vendor.forClass
-- directly rather than going through models/forge.lua: that is the one owner of the class -> house
-- mapping, and a tooltip has no business pulling the whole bench in to read one index.
function MaterialTooltip.houseName(id)
    local def = Material.get(id)
    if not (def and def.class) then return nil end
    local vendorId = Vendor.forClass(def.class)
    local vendor = vendorId and Vendor.get(vendorId)
    return vendor and vendor.name or def.class
end

-- Lay the box out for `id`. Returns nil for an unknown material, so a caller can hand us anything.
function MaterialTooltip.measure(id, player)
    local def = Material.get(id)
    if not def then return nil end

    local title, body, small = fonts()
    local w = MaterialTooltip.WIDTH
    local innerW = w - PAD * 2

    local house = MaterialTooltip.houseName(id)
    local family = house and (house .. "'s stock") or "Craft stock"
    local source = house
        and ("Dropped by caches on quests sponsored by " .. house .. ". Running one house's line stocks another house's bench.")
        or "Dropped by caches at the ends of overworld trails. The further off the main path, the richer the grade and the larger the payout."

    local blocks = {}
    local h = PAD
    h = h + title:getHeight() + 1
    h = h + small:getHeight() + 6

    if def.description then
        local _, lines = body:getWrap(def.description, innerW)
        blocks.descLines = math.max(1, #lines)
        h = h + blocks.descLines * body:getHeight() + 7
    end

    h = h + 1 + 7 -- the hairline rule and its breathing room
    local _, srcLines = small:getWrap(source, innerW)
    blocks.sourceLines = math.max(1, #srcLines)
    h = h + blocks.sourceLines * small:getHeight() + 5
    h = h + small:getHeight() -- the held line
    h = h + PAD

    return {
        id = id, def = def, w = w, h = h,
        family = family, isHouse = house ~= nil, source = source,
        held = player and Player.materialCount(player, id) or nil,
        descLines = blocks.descLines, sourceLines = blocks.sourceLines,
    }
end

-- Paint a measured layout with its top-left pinned exactly at (bx, by). Returns its box rect.
function MaterialTooltip.paint(layout, bx, by)
    if not layout then return nil end
    local title, body, small = fonts()
    local w, h = layout.w, layout.h
    local innerW = w - PAD * 2
    local x, y = bx + PAD, by + PAD

    Theme.set(Theme.panel)
    love.graphics.rectangle("fill", bx, by, w, h, 4, 4)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", bx, by, w, h, 4, 4)

    love.graphics.setFont(title)
    Theme.set(Theme.ink)
    love.graphics.printf(Theme.ellipsize(layout.def.name or layout.id, title, innerW), x, y, innerW, "left")
    y = y + title:getHeight() + 1

    -- The family, in the colour the bill's own chip uses for its edge: house stock cool steel, craft
    -- stock quiet muted. Two families, told apart the same way in both places.
    love.graphics.setFont(small)
    Theme.set(layout.isHouse and Theme.cursor or Theme.muted)
    love.graphics.printf(string.upper(layout.family), x, y, innerW, "left")
    y = y + small:getHeight() + 6

    if layout.def.description then
        love.graphics.setFont(body)
        Theme.set(Theme.ink)
        love.graphics.printf(layout.def.description, x, y, innerW, "left")
        y = y + layout.descLines * body:getHeight() + 7
    end

    Theme.set(Theme.hairline)
    love.graphics.rectangle("fill", x, y, innerW, 1)
    y = y + 1 + 7

    love.graphics.setFont(small)
    Theme.set(Theme.muted)
    love.graphics.printf(layout.source, x, y, innerW, "left")
    y = y + layout.sourceLines * small:getHeight() + 5

    if layout.held then
        Theme.set(Theme.accentAmber)
        love.graphics.printf(layout.held .. " held", x, y, innerW, "left")
    end

    love.graphics.setColor(1, 1, 1)
    return { x = bx, y = by, w = w, h = h }
end

-- The ordinary case: near the cursor, flipped left when it would overhang, clamped on screen.
function MaterialTooltip.draw(id, mx, my, maxRight, player)
    local layout = MaterialTooltip.measure(id, player)
    if not layout then return nil end
    maxRight = maxRight or Scale.WIDTH

    local bx = mx + 14
    local maxX = maxRight - layout.w - 4
    if bx > maxX then bx = mx - layout.w - 14 end
    bx = math.max(4, math.min(bx, maxX))
    local by = math.max(4, math.min(my + 16, Scale.HEIGHT - layout.h - 4))

    return MaterialTooltip.paint(layout, bx, by)
end

return MaterialTooltip
