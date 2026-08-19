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

-- Charges: a stack of three banked bars -- the mark for a purse an item fills and spends whole (the
-- Gleaning Rod's spell-charges, the Reliquary of Tallies' owed dead). Told from the pool glyphs above
-- (a charge is a COUNT the item holds, not a resource the caster pays) and from the hourglass (ticks):
-- a small pile that reads as "how much is banked", down to 0 when the purse is empty.
function Glyphs.charges(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a or 1)
    local barH = h * 0.22
    local gap = (h - barH * 3) / 2
    for i = 0, 2 do
        love.graphics.rectangle("fill", x, y + i * (barH + gap), w, barH, barH * 0.5, barH * 0.5)
    end
end

-- The UNSEEN mark: the red dot worn in the top-right corner of anything the player has not looked at
-- yet -- an item that just landed in the stash, a ware a quest just put on a shelf (Player.markNew).
-- It is a NOTICE, not a status, so it is the one place in the UI that spends a saturated red on
-- something harmless: nothing else on a shelf or in a grid is this colour, which is the whole job.
--
-- Drawn as a filled disc inside a dark rim, because it sits over whatever the icon happens to be --
-- a bright sprite, a tinted plate, a lit border -- and a bare disc loses its edge against the warm
-- ones. Centred on (cx, cy) rather than filling a box: every caller anchors it to a corner.
-- The AT-RISK mark: worn by anything this expedition FOUND rather than marched in with, so a wipe
-- would leave it in a heap on the floor (models/player.lua's Player.atRisk). Descent only -- there is
-- nothing to lose on a campaign board, and nothing draws it there.
--
-- WHAT IT HAS TO SAY IS "THIS FALLS", so it is a downward arrow rather than a warning triangle or a
-- coloured border. A border says "this cell is special" and leaves the player to guess which way; an
-- arrow has a direction, and the direction IS the meaning.
--
-- ONE SHAPE, NOT TWO. It was a satchel with an arrow cut through it -- the pile marker's own silhouette
-- (ui/overworld_map.lua's MarkerIcon.pack), so the mark and the thing it becomes would be the same
-- picture -- and at ten pixels that is not a satchel, it is a dark blob with two gold nubs on it. The
-- bag body is four pixels tall at this size and the arrow cut eats all but its corners. Compound marks
-- need room; a corner badge has none, so it gets the half that carries the meaning.
--
-- THE SAME BONE-GOLD THE PILE MARKER WEARS is what survives of the link, and it is the whole reason
-- this is not simply a red warning: what these items become is that satchel on that tile, and the
-- colour is what the player recognises when they walk back for it. Saturated red is also spoken for --
-- it is the unseen dot, in the opposite corner of the same cell, and two urgent reds on one card would
-- leave neither of them meaning anything.
--
-- Centred on (cx, cy) like the dot above, because every caller anchors it to a corner.
local AT_RISK = { 0.85, 0.76, 0.44 }
function Glyphs.atRisk(cx, cy, size)
    local s = size or 10
    -- A dark plate first: this sits over whatever the item icon happens to be, and a thin gold mark is
    -- invisible over a bright sprite without one. Same reasoning as the unseen dot's rim.
    love.graphics.setColor(0.05, 0.05, 0.06, 0.85)
    love.graphics.rectangle("fill", cx - s * 0.60, cy - s * 0.60, s * 1.20, s * 1.20, s * 0.26)
    love.graphics.setColor(AT_RISK[1], AT_RISK[2], AT_RISK[3])
    -- Stem then head, the head wide enough to still read as a point when the stem is one pixel.
    love.graphics.rectangle("fill", cx - s * 0.11, cy - s * 0.42, s * 0.22, s * 0.42)
    love.graphics.polygon("fill", cx - s * 0.38, cy - s * 0.04, cx + s * 0.38, cy - s * 0.04,
        cx, cy + s * 0.44)
end

local UNSEEN = { 0.851, 0.267, 0.251 }
function Glyphs.unseenDot(cx, cy, radius)
    local r = radius or 4
    love.graphics.setColor(0.05, 0.05, 0.06, 0.85)
    love.graphics.circle("fill", cx, cy, r + 1.5)
    love.graphics.setColor(UNSEEN[1], UNSEEN[2], UNSEEN[3])
    love.graphics.circle("fill", cx, cy, r)
    -- A faint top-left highlight: it is a bead, not a flat hole punched in the plate. Kept small and
    -- dim on purpose -- at this size a bright specular eats the middle of the disc and the mark reads
    -- as a ring instead of a dot.
    love.graphics.setColor(1, 0.80, 0.76, 0.40)
    love.graphics.circle("fill", cx - r * 0.32, cy - r * 0.32, r * 0.28)
end

-- ---------------------------------------------------------------------------
-- Intent marks (models/intent.lua): what an enemy is about to do, on its turn-order card and beside
-- its target line. One shape per kind, in the same fill-the-box, set-your-own-colour contract as the
-- resource glyphs, so the panel lays out a box and the mark draws to it. Kept legible down to ~10px:
-- each is one bold silhouette, no interior detail that silts up at that size.
-- ---------------------------------------------------------------------------

-- Attack: two crossed swords -- hilts at the bottom corners, blades crossing up to the tips. A bare
-- crossed X was rejected because it reads as "cancel / dead"; what makes this pair read as WEAPONS
-- instead is the hilt detail at the bottom -- a pommel dot and a short crossguard on each -- so it is
-- unmistakably two blades meeting, not a strike-through. (An upright single sword was also tried and
-- collapsed into a "+", reading as GAINING; the crossed pair carries the aggression the X never did.)
function Glyphs.intentAttack(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a or 1)
    local lw = love.graphics.getLineWidth()
    love.graphics.setLineWidth(math.max(1.6, w * 0.15))
    local lhx, lhy = x + w * 0.16, y + h * 0.92 -- left hilt (bottom-left)
    local rhx, rhy = x + w * 0.84, y + h * 0.92 -- right hilt (bottom-right)
    love.graphics.line(lhx, lhy, x + w * 0.84, y + h * 0.08) -- blade up-right
    love.graphics.line(rhx, rhy, x + w * 0.16, y + h * 0.08) -- blade up-left
    love.graphics.line(x + w * 0.08, y + h * 0.70, x + w * 0.34, y + h * 0.83) -- left crossguard
    love.graphics.line(x + w * 0.92, y + h * 0.70, x + w * 0.66, y + h * 0.83) -- right crossguard
    love.graphics.setLineWidth(lw)
    local pr = math.max(1, w * 0.10)
    love.graphics.circle("fill", lhx, lhy, pr) -- pommels
    love.graphics.circle("fill", rhx, rhy, pr)
end

-- Cast: a four-point spark -- an offensive SPELL, told from the swords by having no crossing strokes
-- and from the signature sigil (ui/combat_panel's drawSigil) by being solid and small rather than an
-- eight-point star. A bright core sells it as "energy", not "blade".
function Glyphs.intentCast(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a or 1)
    local cx, cy = x + w / 2, y + h / 2
    local o, i = math.min(w, h) * 0.5, math.min(w, h) * 0.16
    love.graphics.polygon("fill",
        cx, cy - o, cx + i, cy - i, cx + o, cy, cx + i, cy + i,
        cx, cy + o, cx - i, cy + i, cx - o, cy, cx - i, cy - i)
end

-- Support: an up-chevron -- a rising arrow for "it is about to LIFT one of its own" (a heal or a
-- buff). Points up so it is the mirror of the debuff's down-chevron; the pair reads as one opposed
-- gesture, good vs. ill, which is exactly the split support/debuff is.
function Glyphs.intentSupport(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a or 1)
    local lw = love.graphics.getLineWidth()
    love.graphics.setLineWidth(math.max(1.8, w * 0.18))
    love.graphics.line(x + w * 0.15, y + h * 0.66, x + w * 0.5, y + h * 0.28)
    love.graphics.line(x + w * 0.5, y + h * 0.28, x + w * 0.85, y + h * 0.66)
    love.graphics.setLineWidth(lw)
end

-- Debuff: a down-chevron -- the falling counterpart, "it is about to drag YOU down" (a stun, a root,
-- a hex). Same stroke as support, flipped, so the two never blur into each other even at 10px.
function Glyphs.intentDebuff(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a or 1)
    local lw = love.graphics.getLineWidth()
    love.graphics.setLineWidth(math.max(1.8, w * 0.18))
    love.graphics.line(x + w * 0.15, y + h * 0.34, x + w * 0.5, y + h * 0.72)
    love.graphics.line(x + w * 0.5, y + h * 0.72, x + w * 0.85, y + h * 0.34)
    love.graphics.setLineWidth(lw)
end

-- Wait: a hollow ring -- "coming for nobody". A held turn is the absence of a strike, so its mark is
-- the quietest, an outline with nothing inside where the others carry a solid shape.
function Glyphs.intentWait(x, y, w, h, r, g, b, a)
    love.graphics.setColor(r, g, b, a or 1)
    local lw = love.graphics.getLineWidth()
    love.graphics.setLineWidth(math.max(1.4, w * 0.12))
    love.graphics.circle("line", x + w / 2, y + h / 2, math.min(w, h) * 0.34)
    love.graphics.setLineWidth(lw)
end

-- Turn: three quarters of a ring with an arrowhead on the open end, the mark every photo viewer and
-- phone camera wears for "rotate this". Drawn rather than typed, because the chrome faces (Alegreya)
-- carry no rotation arrow and a control whose label falls back to a tofu box says nothing at all.
-- `clockwise` picks the direction the head points; the arc opens at the top either way, so the pair
-- read as mirror images of one another.
function Glyphs.turn(x, y, w, h, r, g, b, a, clockwise)
    love.graphics.setColor(r, g, b, a or 1)
    local cx, cy = x + w / 2, y + h / 2
    -- Sized so the head has room to be a HEAD: the ring is a little under a third of the box, leaving
    -- the rest to a triangle wide enough to read the direction at the 18px the drawer draws it.
    local rad = math.min(w, h) * 0.30
    local dir = clockwise and 1 or -1
    -- The break sits at the top of the ring, so the head points across the top -- right for a clockwise
    -- turn, left for a counter-clockwise one. Any other clock position and the two marks read as the
    -- same open ring, which is exactly what happens when the head is too small to see.
    local gap = -math.pi / 2
    local head = 0.62 -- radians of ring the head spans

    local lw = love.graphics.getLineWidth()
    love.graphics.setLineWidth(math.max(1.8, math.min(w, h) * 0.13))
    -- The arc covers the whole ring except the head's sector, drawn from the head round the long way.
    local from = gap + dir * head
    love.graphics.arc("line", "open", cx, cy,
        rad, math.min(from, from + dir * (2 * math.pi - head - 0.12)),
        math.max(from, from + dir * (2 * math.pi - head - 0.12)))
    love.graphics.setLineWidth(lw)

    -- The head: base straddling the ring at the break, tip a little further round the way it turns.
    local tip = gap + dir * head
    local half = rad * 0.52
    love.graphics.polygon("fill",
        cx + rad * math.cos(tip), cy + rad * math.sin(tip),
        cx + (rad + half) * math.cos(gap), cy + (rad + half) * math.sin(gap),
        cx + (rad - half) * math.cos(gap), cy + (rad - half) * math.sin(gap))
end

-- Which mark speaks for which intent kind, so a caller maps a kind straight to a glyph.
Glyphs.INTENT = {
    attack  = Glyphs.intentAttack,
    cast    = Glyphs.intentCast,
    support = Glyphs.intentSupport,
    debuff  = Glyphs.intentDebuff,
    wait    = Glyphs.intentWait,
}

-- RANK: a five-pointed star, filled or hollow. What a body pulled out of the rift is worth
-- (models/voucher.lua's Voucher.starsOf), drawn as a run of these rather than printed as a character
-- for the reason every other mark in this file is a polygon: the UI faces are Alegreya and Alegreya
-- Sans, neither is guaranteed to carry U+2605, and a rank that silently renders as a tofu box on one
-- machine is a rank nobody can read. A drawn mark cannot go missing.
--
-- `hollow` draws the unearned half of a rank, so five pips always occupy the same width and two ranks
-- laid one above the other line up.
function Glyphs.star(x, y, w, h, r, g, b, a, hollow)
    love.graphics.setColor(r, g, b, hollow and (a or 1) * 0.28 or (a or 1))
    local cx, cy = x + w / 2, y + h / 2
    local outer = math.min(w, h) / 2
    local inner = outer * 0.42
    local pts = {}
    -- Ten vertices, alternating outer and inner, starting at the top point (-pi/2) so the star sits
    -- upright rather than resting on a point.
    for i = 0, 9 do
        local ang = -math.pi / 2 + i * math.pi / 5
        local rad = (i % 2 == 0) and outer or inner
        pts[#pts + 1] = cx + math.cos(ang) * rad
        pts[#pts + 1] = cy + math.sin(ang) * rad
    end
    love.graphics.polygon("fill", pts)
end

-- A whole rank in one call: `stars` filled pips out of `outOf`, laid left to right inside (x, y, w, h)
-- with the pips sized to the height. Returns the width actually drawn, so a caller can lay text after
-- it without measuring twice.
function Glyphs.rank(x, y, h, stars, outOf, r, g, b, a, gap)
    outOf = outOf or stars
    gap = gap or math.max(1, h * 0.18)
    for i = 1, outOf do
        Glyphs.star(x + (i - 1) * (h + gap), y, h, h, r, g, b, a, i > stars)
    end
    return outOf * h + (outOf - 1) * gap
end

return Glyphs
