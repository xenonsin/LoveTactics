-- THE RELIC TRAY: an always-on read of what this run is carrying (models/relic.lua), drawn directly
-- under the party vitals so what the company IS and what it is CARRYING read as one block.
--
--   RelicStrip.draw(relicState, x, topY, mx, my)   -- mx/my in logical space, nil off-mouse
--   RelicStrip.height(n)                           -- what it will occupy for n distinct relics
--
-- Purely a reader over Relic.info / Relic.count / Relic.blurbAt; it never mutates the run.
--
-- IT USED TO BE A COLUMN OF NAMED ROWS, pinned to the opposite corner of the screen, and both of those
-- were wrong once relics stacked.
--
--   THE PLACE. The vitals sit at (16, 60) and the relics sat at the right edge, so the two halves of
--   "how is this expedition doing" were as far apart as the screen allows. A player routing a floor looks
--   at one corner; the pile in the other is a thing they check once and then forget.
--
--   THE SIZE. A named row cost 26px and the shelf could only ever hand out nineteen distinct relics, so a
--   column was survivable. The shelf is thirty-six deep now and STACKS -- a real run carries a dozen
--   different relics several deep -- and twelve named rows is 312px of a 720px screen. A 22px chip at six
--   per row holds thirty in three lines.
--
-- SO: chips, not rows. Each wears its RARITY colour (ui/relic_card.lua -- the ladder is the colour now)
-- and its stack count, so the shape of the pile and its power read with no dwell at all. The name lives
-- on the dwell surface, which is the rule for any tile-sized mark: a glyph the player is expected to
-- learn gets its full name next to it on hover, never instead of it.
--
-- THE TOOLTIP READS AT THE CURRENT STACK. Relic.blurbAt resolves the blurb's magnitude against how many
-- copies are actually held, so a chip held three times says what it does at three -- not what the
-- blueprint's base was. A readout that shows the authored number over a deepened relic is the same
-- failure as a preview promising a payout the beat never pays.
--
-- ART DEBT, STATED: there are no relic icons in the tree. A chip draws the shared faceted gem with the
-- def's `mark` (one or two letters) over it, which is a legible stand-in for thirty and an honest
-- placeholder rather than thirty identical gems. When marks land in art/bases/ the mark draw is the one
-- thing that changes here.

local Relic = require("models.relic")
local RelicCard = require("ui.relic_card")
local Theme = require("ui.theme")

local RelicStrip = {}

-- 26 RATHER THAN 22, AND THE REASON IS THE MARK. At 22 the gem is 13px across at its widest and the two
-- letters over it were unreadable on screen -- measured, not guessed. Four pixels buys a 18px gem and a
-- 10pt face, which is the smallest the letterform stays legible at. Six per row still leaves the tray
-- narrower than the party strip above it, and thirty relics still fits in five rows.
local CHIP = 26        -- a chip's box, square
local GAP = 4
local PER_ROW = 6
local PAD = 8
local HEAD_H = 16      -- the "RELICS" caption above the grid

RelicStrip.WIDTH = PER_ROW * CHIP + (PER_ROW - 1) * GAP

local capFont, nameFont, bodyFont, markFont

local function rows(n) return math.max(1, math.ceil(n / PER_ROW)) end

-- The height the tray will occupy for a run holding `n` DISTINCT relics (0 when empty -- nothing is
-- drawn, because an empty tray is not information).
function RelicStrip.height(n)
    if not n or n == 0 then return 0 end
    return HEAD_H + rows(n) * CHIP + (rows(n) - 1) * GAP
end

-- The chip and the dwell surface both live on ui/relic_card.lua now -- the Merchant's relic shelf draws
-- the same two things, and a second copy here would have been the shop and the tray disagreeing about
-- what a relic held twice says it does.
function RelicStrip.draw(relicState, x, topY, mx, my)
    local held = Relic.held(relicState)
    if #held == 0 then return end

    capFont = capFont or Theme.body(11)
    love.graphics.setFont(capFont)
    love.graphics.setColor(Theme.muted[1], Theme.muted[2], Theme.muted[3], 0.75)
    love.graphics.print("RELICS", x, topY)

    local gridY = topY + HEAD_H
    local hovered, hx, hy

    for i, entry in ipairs(held) do
        local col = (i - 1) % PER_ROW
        local row = math.floor((i - 1) / PER_ROW)
        local cx = x + col * (CHIP + GAP)
        local cy = gridY + row * (CHIP + GAP)
        local over = mx and mx >= cx and mx <= cx + CHIP and my >= cy and my <= cy + CHIP
        local info = Relic.info(entry.def) or {}
        info.id = entry.id -- the blurb resolves its magnitude off the id
        if over then hovered, hx, hy = { info = info, count = entry.count }, cx + CHIP + 6, cy end
        RelicCard.chip(cx, cy, CHIP, info, entry.count, { hot = over })
    end

    if hovered then RelicCard.tooltip(hx, hy, hovered.info, hovered.count) end
end

return RelicStrip
