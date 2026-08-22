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
--     would vanish on a foe's bar) and amber (it would vanish on a stamina bar), which leaves a warm
--     near-white (bone), still the lightest thing on any bar.
--     LETHAL can afford to be amber because it only ever draws on a HEALTH bar, and health is only
--     ever blue or red -- never gold.
--
-- These hues are RESHADED to the Etched Atmosphere chrome (ui/theme.lua): every value is a deep
-- ENAMEL jewel tone -- saturation kept for legibility, value dropped so nothing reads "neon" over the
-- dusty bronze-and-bone frame. They resolve from five hue families (steel = ours/mobility, ember =
-- theirs/offence, amethyst = arcane, bronze = exertion/value, verdigris = ally/support) so a new
-- overlay or intent inherits a family instead of inventing a colour. The MEANINGS are unchanged.
--
-- Plain data, no love.graphics at require-time, so it loads under the headless test runner.

local Colors = {
    -- Faction. Also the health-bar fill, on the board and in the HUD.
    PARTY   = { 0.275, 0.463, 0.776 },
    ENEMY   = { 0.749, 0.239, 0.231 },
    -- An ally that fights on our side but ISN'T ours to command -- a rescued survivor, an escort, a
    -- raised body. Green so it never reads as a controllable party member (blue) nor as a foe (red).
    ALLY    = { 0.239, 0.608, 0.380 },

    -- Resource pools (health comes from the faction colours above).
    MANA    = { 0.486, 0.302, 0.745 },
    STAMINA = { 0.839, 0.651, 0.216 },

    -- Deltas an aimed action previews on a pool bar.
    PENDING = { 0.937, 0.906, 0.839 }, -- about to be spent (any pool)
    LETHAL  = { 0.887, 0.756, 0.451 }, -- about to be lost, and it kills (health bars only)
    HEALING = { 0.467, 0.725, 0.566 }, -- about to be gained

    -- Tile overlay bands.
    RANGE   = { 0.749, 0.239, 0.231 }, -- offensive reach
    SUPPORT = { 0.239, 0.608, 0.380 }, -- heal / buff reach
    -- The reach of a cast aimed at a foe that does it no harm (Combat.isHarmlessAbility -- the
    -- Assayer's Eye). A cool steel-cyan: it must not read as the threat red beside it, and it must
    -- not read as the kindness green either, since it can only ever land on the other side.
    HARMLESS = { 0.404, 0.678, 0.729 },
    MOVE    = { 0.275, 0.463, 0.776 }, -- reachable move tiles
    DANGER  = { 0.486, 0.302, 0.745 }, -- tiles a foe could also strike
    AOE     = { 0.749, 0.239, 0.231 }, -- armed blast footprint
}

-- Intent kinds (models/intent.lua): the colour a predicted enemy action wears on its target line and
-- its turn-order icon. Reuses the overlay vocabulary where it already means the same thing -- an
-- attack is RANGE red, a heal/buff is SUPPORT green, a debuff borrows STAMINA's amber -- and CAST
-- takes MANA's purple, because a spell is the one intent already tied to that pool. `wait` is a muted
-- grey: a unit coming for nobody should read as the quietest mark on the board.
Colors.INTENT = {
    attack  = Colors.RANGE,
    cast    = Colors.MANA,
    support = Colors.SUPPORT,
    debuff  = { 0.865, 0.707, 0.341 },
    wait    = { 0.604, 0.627, 0.675 },
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
    return Colors.allegiance(unit.side, unit.control)
end

-- The same answer off a bare (side, control) pair rather than off a unit. Split out because the
-- allegiance a body is DRAWN with is not always the one it currently holds: a Charm flips the unit in
-- the model the instant the cast resolves, but the view must keep drawing the old colours until the
-- blow that turned it is seen to land (ui/combat_fx.lua's shownAllegiance, which reads the pre-charm
-- side back off the unit and hands it here). The rule about which colour a pair maps to lives in one
-- place all the same -- two copies of it is how the board and the turn strip start disagreeing.
function Colors.allegiance(side, control)
    if side == "party" and (control == "ai" or control == "none") then
        return Colors.ALLY
    end
    return Colors.side(side)
end

-- `color` darkened toward empty by `ratio` (1 = full, 0 = empty), as r, g, b. Lets a health bar
-- keep its side's hue while still reading as drained -- the job the old green->red gradient did.
function Colors.drain(color, ratio)
    local k = 0.55 + 0.45 * math.max(0, math.min(1, ratio))
    return color[1] * k, color[2] * k, color[3] * k
end

return Colors
