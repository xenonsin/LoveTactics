-- WHO IS BEHIND THIS COUNTER, as one pane every room in the city draws the same way.
--
-- A house is a shopkeeper with a desk (models/counter.lua), and the rooms behind that desk are not all
-- shops: the Bastion's bench, the Cathedral's ward, the Colosseum's sand and the Touchstone's reading
-- are counters with somebody standing at them just as much as a shelf is. They shipped without one. So
-- a player who pressed "I have work for the forge" watched the keeper's face, their name and their
-- line disappear on the way through a door that was supposed to lead TO them.
--
-- THE PANE WAS DELETED FROM EVERY PANEL ONCE AND CAME BACK IN EXACTLY ONE. It went because it was a
-- tinted plate standing in for a painting nobody had commissioned; it came back in ui/panels/shop.lua
-- with a real fallback behind it -- the house's own MARK, big and in the house's own colour
-- (ui/vendor_icons.lua) -- which is a shape the player already meets on a shop's title and alone on a
-- 32px tile out on the ground. A pane carrying that says something true about the house rather than
-- drawing a hole where a painting goes, so it is a placeholder that can ship.
--
-- That file's own note said the rest should take its numbers. This is that, lifted out whole: the same
-- 236 x 380, the same foot-pinned crop, the same name plate, the same line underneath. One copy rather
-- than seven, because a keeper pane that drifts per room is the city's one fixed landmark drifting --
-- a player who has stood at one counter should know where to look at the next one.
--
-- THE FACE IS THE VENDOR'S OWN and not the house's companion. That was tried and reversed: fronting
-- each room with the companion would mean no vendor ever needs a face, the six portraits already in
-- the budget doing triple duty, and every counter being somebody you are on your way to recruiting --
-- which is a different relationship from the one a counter wants. A shopkeeper is somebody you buy
-- from and keep buying from; a companion is met on a floor and leaves with you (models/errand.lua).
--
-- HOST OWNS THE RECT. This draws into the box it is handed and reports the y it finished at; nothing
-- here knows what panel it is in, where the purse goes or what is beside it.

local Sprite = require("models.sprite")
local Theme = require("ui.theme")
local Vendor = require("models.vendor")
local VendorIcons = require("ui.vendor_icons")

local Keeper = {}

-- The pane, and the exemplar every room takes. Width first, because the column it stands in is what
-- the rest of a panel is measured off.
Keeper.W, Keeper.H = 236, 380

-- The dark plate along the pane's foot that the name is printed on, over whatever is behind it -- so a
-- face and a mark both get named in the same place.
local PLATE_H = 30
-- The gap between the pane and the house's line under it.
local LINE_GAP = 12

-- The blueprint behind an id, or nil. Public because a host usually wants the same table for its own
-- header, and asking twice is how two readings of one house end up disagreeing.
function Keeper.def(vendorId)
    return vendorId and Vendor.defs[vendorId] or nil
end

-- Draw the pane at (x, y, w, h) and the house's line beneath it. Returns the y the block ended at, so
-- a caller can stack under it without re-deriving the arithmetic.
--
--   opts.nameFont     the plate's face (defaults to the theme's body)
--   opts.lineFont     the line under the pane (defaults to the theme's small)
--   opts.title        what to call the keeper when the blueprint has no `name` -- the room's own title
--   opts.line         the sentence under the pane; `false` draws none, nil takes the vendor's own
function Keeper.draw(vendorId, x, y, w, h, opts)
    opts = opts or {}
    w = w or Keeper.W
    h = h or Keeper.H
    local def = Keeper.def(vendorId)

    Theme.set(Theme.slot)
    love.graphics.rectangle("fill", x, y, w, h, Theme.R, Theme.R)
    Theme.set(Theme.frame)
    love.graphics.rectangle("line", x, y, w, h, Theme.R, Theme.R)

    -- A missing file resolves to its own path string (models/sprite.lua), so an uncommissioned portrait
    -- falls through to the mark rather than crashing -- which is the whole of the art debt here and the
    -- reason this pane is allowed to ship before any of it lands.
    local art = def and def.portrait and Sprite.load(def.portrait)
    if type(art) == "userdata" then
        local sw, sh = art:getDimensions()
        -- Fitted to the pane and pinned to its FOOT, the way a bust stands on a line rather than
        -- floating in a box: a portrait taller than it is wide crops from the top, never the chin.
        local scale = math.max(w / sw, h / sh)
        love.graphics.setScissor(x + 1, y + 1, w - 2, h - 2)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(art, x + w / 2, y + h, 0, scale, scale, sw / 2, sh)
        love.graphics.setScissor()
    else
        local r, g, b = VendorIcons.color(vendorId)
        local size = w * 0.52
        VendorIcons.draw(vendorId, x + w / 2 - size / 2, y + h / 2 - size * 0.62,
            size, size, r or 0.6, g or 0.6, b or 0.7, 0.5)
    end

    local nameFont = opts.nameFont or Theme.body(17)
    love.graphics.setColor(0, 0, 0, 0.62)
    love.graphics.rectangle("fill", x + 1, y + h - PLATE_H - 1, w - 2, PLATE_H, 0, 0, Theme.R, Theme.R)
    love.graphics.setFont(nameFont)
    Theme.set(Theme.accentAmber)
    local who = (def and def.name) or opts.title or ""
    love.graphics.printf(Theme.ellipsize(who, nameFont, w - 20),
        x, y + h - PLATE_H + 5, w, "center")

    local bottom = y + h
    if opts.line ~= false then
        local line = opts.line or (def and def.description) or ""
        if line ~= "" then
            local lineFont = opts.lineFont or Theme.body(13)
            love.graphics.setFont(lineFont)
            Theme.set(Theme.muted)
            love.graphics.printf(line, x, bottom + LINE_GAP, w, "left")
            local _, wrapped = lineFont:getWrap(line, w)
            bottom = bottom + LINE_GAP + #wrapped * lineFont:getHeight()
        end
    end
    return bottom
end

return Keeper
