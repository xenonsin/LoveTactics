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

-- Which mark speaks for which intent kind, so a caller maps a kind straight to a glyph.
Glyphs.INTENT = {
    attack  = Glyphs.intentAttack,
    cast    = Glyphs.intentCast,
    support = Glyphs.intentSupport,
    debuff  = Glyphs.intentDebuff,
    wait    = Glyphs.intentWait,
}

return Glyphs
