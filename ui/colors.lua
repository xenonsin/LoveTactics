-- Shared board/HUD palette. Every colour that MEANS something lives here, so the meanings stay
-- consistent everywhere a unit is drawn: the board tile, the turn-order card, and the tooltip.
--
-- The scheme:
--   * A unit's SIDE is carried by its health bar -- blue for ours, red for theirs -- everywhere a
--     unit appears. Health is the pool every unit has, so it's the one bar always available to say
--     whose unit this is. Its hue is spent on the side, NOT on how hurt the unit is; the bar's
--     LENGTH already reads the ratio, and `Colors.drain` darkens it toward empty.
--   * Because blue now means "ours", mana is PURPLE -- a blue mana bar beside a blue ally bar would
--     be two different meanings in one hue.
--   * Tile overlays keep the range/move/support/danger hues. RANGE deliberately shares red with
--     ENEMY and MOVE shares blue with PARTY: overlays are washes on a TILE, faction is a bar on a
--     UNIT, so they never compete for the same mark.
--   * PENDING (the slice an aimed action is about to spend) is drawn ON TOP of a pool bar, so it
--     must contrast every pool colour at once -- red, blue, purple AND gold. That rules out red (it
--     would vanish on a foe's bar) and amber (it would vanish on a stamina bar), which leaves white.
--     LETHAL can afford to be amber because it only ever draws on a HEALTH bar, and health is only
--     ever blue or red -- never gold.
--
-- Plain data, no love.graphics at require-time, so it loads under the headless test runner.

local Colors = {
    -- Faction. Also the health-bar fill, on the board and in the HUD.
    PARTY   = { 0.40, 0.70, 1.00 },
    ENEMY   = { 0.95, 0.35, 0.32 },
    -- An ally that fights on our side but ISN'T ours to command -- a rescued survivor, an escort, a
    -- raised body. Green so it never reads as a controllable party member (blue) nor as a foe (red).
    ALLY    = { 0.40, 0.82, 0.45 },

    -- Resource pools (health comes from the faction colours above).
    MANA    = { 0.62, 0.42, 0.95 },
    STAMINA = { 0.90, 0.75, 0.30 },

    -- Deltas an aimed action previews on a pool bar.
    PENDING = { 0.96, 0.96, 0.99 }, -- about to be spent (any pool)
    LETHAL  = { 1.00, 0.78, 0.22 }, -- about to be lost, and it kills (health bars only)
    HEALING = { 0.55, 0.92, 0.58 }, -- about to be gained

    -- Tile overlay bands.
    RANGE   = { 1.00, 0.32, 0.30 }, -- offensive reach
    SUPPORT = { 0.35, 0.85, 0.40 }, -- heal / buff reach
    MOVE    = { 0.30, 0.60, 1.00 }, -- reachable move tiles
    DANGER  = { 0.65, 0.30, 0.90 }, -- tiles a foe could also strike
    AOE     = { 1.00, 0.42, 0.30 }, -- armed blast footprint
}

-- The side colour for a "party"/"enemy" side string -- the unit's identity everywhere it's drawn.
function Colors.side(side)
    return side == "party" and Colors.PARTY or Colors.ENEMY
end

-- A unit's display colour. Side gives the base (blue ours / red theirs), but a unit that stands on
-- our side WITHOUT being under our command -- an AI-run escort or survivor, a raised body, a decoy
-- (control "ai"/"none") -- reads GREEN, so "can I move this one?" is legible at a glance and a
-- neutral is never mistaken for a party member. A "remote" opponent's unit is not ours, so it keeps
-- its side colour. Falls back to Colors.side for anything that isn't a unit table.
function Colors.unit(unit)
    if type(unit) ~= "table" then return Colors.side(unit) end
    if unit.side == "party" and (unit.control == "ai" or unit.control == "none") then
        return Colors.ALLY
    end
    return Colors.side(unit.side)
end

-- `color` darkened toward empty by `ratio` (1 = full, 0 = empty), as r, g, b. Lets a health bar
-- keep its side's hue while still reading as drained -- the job the old green->red gradient did.
function Colors.drain(color, ratio)
    local k = 0.55 + 0.45 * math.max(0, math.min(1, ratio))
    return color[1] * k, color[2] * k, color[3] * k
end

return Colors
