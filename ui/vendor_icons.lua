-- ONE MARK PER HOUSE, AND ONE COLOUR.
--
-- A vendor is named everywhere -- on a quest board row, on a shop's header, on the piece of work
-- standing out on the ground -- and until now it was named in WORDS everywhere, which a 32px map tile
-- has no room for. So the seven houses that post work (and the four that only keep a counter) each get
-- a small vector mark, drawn the way ui/glyphs.lua draws its own: fill the box you are handed, shade
-- your own detail off the colour the caller set.
--
-- WHAT THE MARK IS OF. Each house is named for an object -- a bastion, a crucible, a lodge with antlers
-- on every beam -- and the mark is that object rather than a symbol of what the house SELLS. The shelf
-- moves (an item can change class, a discipline can open a new rung); the building does not, and the
-- name on its door is the one thing about a house that is fixed. It also keeps the marks from
-- collapsing into seven weapons, which is what "draw what they sell" would have produced.
--
-- WHERE IT IS READ, and why one mark has to serve all three:
--   * ui/overworld_map.lua      -- the writ standing on a ground: WHOSE work this is, at a glance,
--                                  across a board that can be carrying three houses' quests at once;
--   * states/game.lua           -- the day's checklist, where the same mark sits beside the sentence
--                                  that says what the work IS. That row is the map's legend;
--   * ui/panels/quest_board.lua -- beside the house's own NAME, which is where the mark is learned.
--
-- The order matters: a player meets the mark next to the words, then meets it alone on the ground. A
-- mark that only ever appeared on the tile would be a rebus.
--
-- Kin to ui/glyphs.lua (a mark beside a number) and ui/status_badge.lua (a whole badge). Kept out of
-- glyphs.lua because these are keyed by a DATA id -- add data/vendors/<id>.lua and this file owes it a
-- mark AND a colour, both of which tests/vendor_icon_spec.lua enforces -- where a glyph is keyed by a
-- concept. The colours are the second half of the identity and live at the bottom of this file.

local VendorIcons = {}

-- vendor id -> mark. Each fills (x, y, w, h) with the base colour the caller passes, and shades its own
-- detail off it -- a dark pass at ~0.16 for a VOID (something the mark is missing: a keyhole, an eye
-- slit, the mouth of a pot) and ~0.35 for a SEAM (a shadow inside the object: a spine, a shield band).
local Marks = {}

-- THE BASTION -- a kite shield. The house of the oath kept, and a shield is the only piece of a
-- knight's kit that is nothing but the promise to stand somewhere. Broad at the shoulder and tapering
-- to a point, which is the silhouette no other mark on the board has.
function Marks.bastion(x, y, w, h, r, g, b, a)
    local cx = x + w / 2
    love.graphics.setColor(r, g, b, a)
    love.graphics.polygon("fill",
        x, y + h * 0.04,
        x + w, y + h * 0.04,
        x + w, y + h * 0.52,
        cx, y + h,
        x, y + h * 0.52)
    love.graphics.setColor(r * 0.35, g * 0.35, b * 0.35, a)
    love.graphics.rectangle("fill", cx - w * 0.09, y + h * 0.04, w * 0.18, h * 0.66)
end

-- THE COLOSSEUM -- the portcullis under the stands. Sand, blood and a crowd, and the one object every
-- fighter in that house meets: the gate you are let out of. Nothing else about a Colosseum survives
-- being drawn small -- a bowl is an oval, a crowd is noise -- but a barred gate is pure geometry, and
-- the gaps between the bars do the work at fourteen pixels rather than any detail inside them.
--
-- A crested helm was drawn here first and did not carry: at 1x the crest merges with the skull and the
-- whole mark reads as a bell. Three bars, spaced as wide as they are thick, cannot do that.
function Marks.colosseum(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a)
    love.graphics.rectangle("fill", x, y, w, h * 0.18, 2, 2)
    for i = 0, 2 do
        local bx = x + w * (0.10 + i * 0.32)
        love.graphics.rectangle("fill", bx, y + h * 0.14, w * 0.18, h * 0.64)
        -- ...and every bar ends in a point, which is what tells a gate from a fence.
        love.graphics.polygon("fill",
            bx, y + h * 0.78,
            bx + w * 0.18, y + h * 0.78,
            bx + w * 0.09, y + h)
    end
end

-- THE ARCANUM -- an open book. A library that has outlived every scholar who swore he could read it
-- safely, so the mark is the thing that did the outliving. Two pages meeting at a dark spine: the
-- scroll (a posted writ, MarkerIcon.quest) is broader at its ends, this is broader at its edges.
function Marks.arcanum(x, y, w, h, r, g, b, a)
    local cx = x + w / 2
    love.graphics.setColor(r, g, b, a)
    love.graphics.polygon("fill", x, y + h * 0.20, cx, y + h * 0.34, cx, y + h * 0.94, x, y + h * 0.80)
    love.graphics.polygon("fill", x + w, y + h * 0.20, cx, y + h * 0.34, cx, y + h * 0.94,
        x + w, y + h * 0.80)
    love.graphics.setColor(r * 0.35, g * 0.35, b * 0.35, a)
    love.graphics.setLineWidth(math.max(1.5, w * 0.09))
    love.graphics.line(cx, y + h * 0.34, cx, y + h * 0.94)
    love.graphics.setLineWidth(1)
end

-- THE CATHEDRAL -- a cross. Cold stone and colder certainty, and the mark is the certainty. Drawn with
-- a heavy bar high on the upright so it reads as architecture rather than as a plus sign; the shrine's
-- own mark (an altar under a flame) is a squat, ground-hugging shape and shares nothing with this.
function Marks.cathedral(x, y, w, h, r, g, b, a)
    local cx = x + w / 2
    love.graphics.setColor(r, g, b, a)
    love.graphics.rectangle("fill", cx - w * 0.14, y, w * 0.28, h)
    love.graphics.rectangle("fill", x, y + h * 0.24, w, h * 0.24)
end

-- THE CRUCIBLE -- the pot itself. Every jar is labelled with something else's name, and a crucible is
-- the vessel that makes that possible: whatever goes in comes out as something it was not. A heavy
-- overhanging lip over a body that tapers DOWN, which is the reverse of the treasure chest and of every
-- other container on the board.
function Marks.alchemist(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a)
    love.graphics.rectangle("fill", x, y + h * 0.24, w, h * 0.16, 2, 2)
    love.graphics.polygon("fill",
        x + w * 0.12, y + h * 0.40,
        x + w * 0.88, y + h * 0.40,
        x + w * 0.70, y + h,
        x + w * 0.30, y + h)
    love.graphics.setColor(r * 0.16, g * 0.16, b * 0.18, a)
    love.graphics.rectangle("fill", x + w * 0.20, y + h * 0.24, w * 0.60, h * 0.09)
end

-- HUNTER'S LODGE -- antlers. Antlers on every beam; they ask what you killed before they ask your name.
-- The one mark here that is a TROPHY rather than a tool, which is the whole of what the house is.
-- Branching lines rather than a filled shape: a solid rack turns to a blot at sixteen pixels.
function Marks.hunters_lodge(x, y, w, h, r, g, b, a)
    local cx = x + w / 2
    love.graphics.setColor(r, g, b, a)
    love.graphics.setLineWidth(math.max(2, w * 0.13))
    for _, s in ipairs({ -1, 1 }) do
        local function px(t) return cx + s * w * t end
        love.graphics.line(px(0.05), y + h, px(0.26), y + h * 0.52, px(0.40), y + h * 0.04)
        love.graphics.line(px(0.26), y + h * 0.52, px(0.56), y + h * 0.22)
        love.graphics.line(px(0.14), y + h * 0.76, px(0.44), y + h * 0.52)
    end
    love.graphics.setLineWidth(1)
end

-- THE UNDERCROFT -- a keyhole. No sign, no door you would notice, and everything inside belonged to
-- someone else: the mark is the door you are not supposed to find, cut as a VOID in a plate.
-- Deliberately not a key -- the board already prints a key for the thing you pick up and spend on a gate.
function Marks.undercroft(x, y, w, h, r, g, b, a)
    local cx = x + w / 2
    love.graphics.setColor(r, g, b, a)
    love.graphics.rectangle("fill", x + w * 0.10, y, w * 0.80, h, w * 0.16)
    love.graphics.setColor(r * 0.16, g * 0.16, b * 0.18, a)
    love.graphics.circle("fill", cx, y + h * 0.38, w * 0.19)
    love.graphics.polygon("fill",
        cx - w * 0.09, y + h * 0.42,
        cx + w * 0.09, y + h * 0.42,
        cx + w * 0.16, y + h * 0.80,
        cx - w * 0.16, y + h * 0.80)
end

-- The four houses that post no work. They keep marks anyway, because a mark is how a house is named in
-- a place too small for its name, and all four of them are named in exactly such places -- the hub's
-- own rows, a shop header, the Crossing's token count.

-- THE CAFE -- a bowl with the steam coming off it. One hot meal before the road.
function Marks.cafe(x, y, w, h, r, g, b, a)
    local cx = x + w / 2
    love.graphics.setColor(r, g, b, a)
    love.graphics.arc("fill", cx, y + h * 0.62, w * 0.44, 0, math.pi)
    love.graphics.rectangle("fill", x, y + h * 0.56, w, h * 0.10, 2, 2)
    love.graphics.setLineWidth(math.max(1.5, w * 0.09))
    love.graphics.line(cx - w * 0.16, y + h * 0.38, cx - w * 0.04, y + h * 0.24,
        cx - w * 0.16, y + h * 0.10)
    love.graphics.line(cx + w * 0.08, y + h * 0.38, cx + w * 0.20, y + h * 0.24,
        cx + w * 0.08, y + h * 0.10)
    love.graphics.setLineWidth(1)
end

-- THE INN -- a bed, seen from the side. A bed, a fire and a surgeon; the bed is the part you buy.
function Marks.inn(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a)
    love.graphics.rectangle("fill", x, y + h * 0.26, w * 0.16, h * 0.62, 2, 2)          -- headboard
    love.graphics.rectangle("fill", x, y + h * 0.60, w, h * 0.28, 2, 2)                 -- mattress
    love.graphics.rectangle("fill", x + w * 0.20, y + h * 0.44, w * 0.30, h * 0.18, 2, 2) -- pillow
    love.graphics.setColor(r * 0.35, g * 0.35, b * 0.35, a)
    love.graphics.rectangle("fill", x + w * 0.20, y + h * 0.58, w * 0.80, h * 0.05)
end

-- THE CROSSING -- the tear itself, held open. A jagged vertical shard: the one mark here that is not an
-- object at all, because what the Crossing sells is a hole in the world lasting long enough to walk
-- through.
function Marks.crossing(x, y, w, h, r, g, b, a)
    local cx = x + w / 2
    love.graphics.setColor(r, g, b, a)
    love.graphics.polygon("fill",
        cx - w * 0.06, y,
        cx + w * 0.16, y + h * 0.28,
        cx + w * 0.02, y + h * 0.50,
        cx + w * 0.18, y + h,
        cx - w * 0.10, y + h * 0.66,
        cx + w * 0.01, y + h * 0.44,
        cx - w * 0.18, y + h * 0.20)
end

-- THE TOUCHSTONE -- the stone, and the streak struck across it. Bring up what nobody can name; the mark
-- it leaves on the stone is the answer, which is why the streak is drawn and not merely implied.
function Marks.touchstone(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a)
    love.graphics.polygon("fill",
        x + w * 0.32, y + h * 0.02,
        x + w * 0.70, y,
        x + w * 0.88, y + h * 0.50,
        x + w * 0.72, y + h,
        x + w * 0.28, y + h,
        x + w * 0.14, y + h * 0.44)
    love.graphics.setColor(r * 0.16, g * 0.16, b * 0.18, a)
    love.graphics.setLineWidth(math.max(2, w * 0.12))
    love.graphics.line(x + w * 0.26, y + h * 0.74, x + w * 0.76, y + h * 0.24)
    love.graphics.setLineWidth(1)
end

-- ---------------------------------------------------------------------------
-- AND ONE COLOUR PER HOUSE
--
-- The mark alone was not enough. Every piece of posted work wore the ENDS' GOLD -- the wash said "an
-- end you can finish today" and the mark said whose -- which is the right split for a category with one
-- member and the wrong one here: gold is what the board's own end wears, the guard on the way down, the
-- thing the whole day is pointed at. Seven houses sharing the boss's colour meant the loudest signal on
-- the map was spent saying "somebody's work", which is true of nearly every marker on a campaign
-- ground. So the gold goes back to being the BOSS alone, and a house's writ takes the house's own hue.
--
-- TWO COLOURS ARE RESERVED AND NO HOUSE MAY HAVE THEM: the ends' gold (an objective -- see
-- ui/overworld_map.lua's markerColor) and the hostile red (a fight). Those two answer the questions
-- asked most often and fastest -- is this the thing I came for, is this something that will hit me --
-- and a house hue that could be mistaken for either would cost more than it bought.
--
-- What is left is the wheel from chartreuse round to magenta, and the seven are spread across it about
-- fifty degrees apart, assigned by the house's own sin where the wheel allowed: sloth's blue, pride's
-- violet, lust's magenta, gluttony's green, envy's acid. Two could not have theirs and are the reason
-- the mapping is not simply "the sin's colour" -- greed's gold IS the boss's, and wrath's red IS the
-- fight's. The Undercroft took verdigris (a cellar, and the one house whose colour is a place rather
-- than a passion) and the Colosseum took the SAND -- pale, warm and nearly unsaturated, which is the
-- one direction left that gold cannot be confused with.
--
-- Adjacency that is accepted rather than missed: a treasure chest sits near the Undercroft's verdigris
-- and a heroic spirit near the Lodge's green. Both are descent furniture rather than a campaign
-- ground's, and both carry a shape nothing else has -- the colour narrows, the mark settles.
local Colors = {
    alchemist     = { 0.62, 0.94, 0.28 }, -- acid, and kept well clear of gold: the melt in the pot (envy)
    hunters_lodge = { 0.34, 0.78, 0.34 }, -- deep forest green (gluttony)
    undercroft    = { 0.20, 0.82, 0.66 }, -- verdigris on old silver: a cellar nobody signs for
    bastion       = { 0.36, 0.62, 0.96 }, -- cold steel blue (sloth)
    arcanum       = { 0.66, 0.42, 0.98 }, -- violet (pride)
    cathedral     = { 0.98, 0.40, 0.78 }, -- stained glass at the west end (lust)
    colosseum     = { 0.94, 0.86, 0.68 }, -- the sand itself: what wrath cannot have the red for
    -- The four houses that post no work keep colours too, so nothing has to special-case them, and so
    -- the spacing rule below is one rule over eleven rather than a rule with four exemptions.
    cafe          = { 0.96, 0.56, 0.52 }, -- a hot plate
    inn           = { 0.72, 0.78, 0.94 }, -- a cold room and a warm bed
    crossing      = { 0.30, 0.30, 0.88 }, -- the deep indigo of what comes through the tear
    touchstone    = { 0.58, 0.64, 0.72 }, -- the stone
}

-- A house's colour as three components, or nil for a house that has none. Three returns rather than the
-- table itself, because every caller feeds it straight into love.graphics.setColor or a plate.
function VendorIcons.color(vendorId)
    local c = vendorId and Colors[vendorId]
    if not c then return nil end
    return c[1], c[2], c[3]
end

-- Does this house have a mark? Asked by anything that has to lay out a row BEFORE it draws one, and by
-- callers with a fallback of their own (the map still has a writ to draw for unsponsored work).
function VendorIcons.has(vendorId)
    return vendorId ~= nil and Marks[vendorId] ~= nil
end

-- Draw `vendorId`'s mark into (x, y, w, h). Returns false and draws NOTHING for a house with no mark or
-- for a nil id, so a caller can fall back rather than having to ask first -- the Gate Below is sponsored
-- by nobody, and a board can carry it.
function VendorIcons.draw(vendorId, x, y, w, h, r, g, b, a)
    local mark = vendorId and Marks[vendorId]
    if not mark then return false end
    mark(x, y, w, h, r or 1, g or 1, b or 1, a or 1)
    return true
end

-- Every id this file has a mark for, for a spec that has to check the set both ways round.
function VendorIcons.ids()
    local out = {}
    for id in pairs(Marks) do out[#out + 1] = id end
    table.sort(out)
    return out
end

return VendorIcons
