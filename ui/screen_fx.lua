-- The screen-space effect controller: the one place that holds "how hard is the frame reacting right
-- now" and decays it over time. scale.lua reads it when it blits the logical canvas to the window
-- (shake offset + the shaders/screen.lua post terms); states raise effects through the verbs below.
--
-- A MODULE, not an instance -- there is exactly one screen, and a battle, the hub and a conversation
-- all share it. State lives in `S` so a reload during a test starts clean.
--
--   ScreenFx.shake(mag, time)          -- a positional rumble, px, decaying to 0 over `time`
--   ScreenFx.punch(amount)             -- a one-off radial zoom+chroma kick (a killing blow)
--   ScreenFx.flash(color, time)        -- a full-frame additive beat, fading over `time`
--   ScreenFx.freeze(time)              -- hit-stop: gameplay time is scaled toward 0 for `time`
--   ScreenFx.grey(target)              -- ramp desaturation toward `target` (defeat); 0 releases it
--   ScreenFx.blur(amount)              -- set the modal-background blur radius (0 clears)
--   ScreenFx.vignette(amount, color)   -- set the edge darkening (a low-HP pulse); 0 clears
--   ScreenFx.update(dt)                -- advance every decay on REAL dt (main.lua, once a frame)
--   ScreenFx.timeScale()               -- the gameplay dt multiplier a freeze imposes (battle reads it)
--   ScreenFx.shakeOffset() / ScreenFx.post()  -- what scale.lua reads at blit time
--
-- ---------------------------------------------------------------------------
-- REDUCED EFFECTS. Every verb that MOVES THE FRAME -- shake, punch, flash, freeze -- checks the
-- `reduced_effects` preference (models/settings.lua) and does nothing when it is on. The verbs that
-- only tint or darken (grey, vignette, blur) are left alone: they carry meaning (you have lost; your
-- leader is dying; a panel is open) rather than motion, and a player who asked for less motion did not
-- ask to be told less. That split is the whole reason the setting's description promises what it does.
-- ---------------------------------------------------------------------------

local Settings = require("models.settings")

local ScreenFx = {}

-- All live state in one table, so ScreenFx.reset() (and a test's reload) is a single assignment.
local S = {
    shakeMag = 0, shakeT = 0, shakeDur = 0,
    punch = 0,
    flash = 0, flashDur = 0, flashColor = { 1, 1, 1 },
    freezeT = 0,
    desat = 0, desatTarget = 0,
    blur = 0,
    vignette = 0, vignetteColor = { 0.6, 0.05, 0.05 },
}
ScreenFx._state = S

local function reduced()
    return Settings.get("reduced_effects") == true
end

function ScreenFx.reset()
    S.shakeMag, S.shakeT, S.shakeDur = 0, 0, 0
    S.punch = 0
    S.flash, S.flashDur = 0, 0
    S.freezeT = 0
    S.desat, S.desatTarget = 0, 0
    S.blur = 0
    S.vignette = 0
end

-- ---------------------------------------------------------------------------
-- Verbs
-- ---------------------------------------------------------------------------

function ScreenFx.shake(mag, time)
    if reduced() then return end
    -- A stronger shake overrides a weaker one still ringing, rather than the two summing into a mess.
    if (mag or 0) >= S.shakeMag then
        S.shakeMag = mag or 0
        S.shakeDur = time or 0.3
        S.shakeT = S.shakeDur
    end
end

function ScreenFx.punch(amount)
    if reduced() then return end
    S.punch = math.max(S.punch, amount or 0.6)
end

function ScreenFx.flash(color, time)
    if reduced() then return end
    S.flash = 1
    S.flashDur = time or 0.25
    S.flashColor = color or { 1, 1, 1 }
end

function ScreenFx.freeze(time)
    if reduced() then return end
    S.freezeT = math.max(S.freezeT, time or 0.06)
end

-- Meaning, not motion: these ignore reduced_effects.
function ScreenFx.grey(target) S.desatTarget = target or 0 end
function ScreenFx.blur(amount) S.blur = amount or 0 end
function ScreenFx.vignette(amount, color)
    S.vignette = amount or 0
    if color then S.vignetteColor = color end
end

-- ---------------------------------------------------------------------------
-- Advance (real dt) and read-outs
-- ---------------------------------------------------------------------------

function ScreenFx.update(dt)
    dt = dt or 0
    if S.shakeT > 0 then
        S.shakeT = S.shakeT - dt
        if S.shakeT <= 0 then S.shakeT, S.shakeMag, S.shakeDur = 0, 0, 0 end
    end
    -- The punch snaps in and springs back fast -- an exponential fall reads as a recoil, not a fade.
    if S.punch > 0 then
        S.punch = S.punch - dt * 5
        if S.punch < 0.001 then S.punch = 0 end
    end
    if S.flash > 0 and S.flashDur > 0 then
        S.flash = S.flash - dt / S.flashDur
        if S.flash < 0 then S.flash = 0 end
    end
    if S.freezeT > 0 then
        S.freezeT = S.freezeT - dt
        if S.freezeT < 0 then S.freezeT = 0 end
    end
    -- Desaturation eases toward its target both ways (a defeat closes in; a retry opens back up).
    if math.abs(S.desat - S.desatTarget) > 0.001 then
        S.desat = S.desat + (S.desatTarget - S.desat) * math.min(1, dt * 3)
    else
        S.desat = S.desatTarget
    end
end

-- The gameplay dt multiplier: 0 while a hit-stop holds, 1 otherwise. Battle multiplies its own dt by
-- this so the freeze bites the simulation without touching ScreenFx's own real-time decays above, or
-- the hub/overworld/conversation, which never call it.
function ScreenFx.timeScale()
    return S.freezeT > 0 and 0 or 1
end

-- The pixel offset scale.lua adds to the canvas blit. A decaying sinusoid, so the rumble settles.
function ScreenFx.shakeOffset()
    if S.shakeT <= 0 or S.shakeMag <= 0 then return 0, 0 end
    local p = S.shakeT / S.shakeDur                  -- 1 -> 0
    local m = S.shakeMag * p
    return math.sin(S.shakeT * 90) * m, math.cos(S.shakeT * 71) * m * 0.8
end

-- Everything the screen shader needs this frame, plus whether it is worth binding at all. scale.lua
-- skips the shader entirely when `active` is false -- a still frame pays nothing.
function ScreenFx.post()
    local active = S.punch > 0.001 or S.blur > 0.001 or S.desat > 0.001
        or S.vignette > 0.001 or S.flash > 0.001
    return {
        active = active,
        punch = S.punch,
        blur = S.blur,
        desat = S.desat,
        vignette = S.vignette,
        vignetteColor = S.vignetteColor,
        flash = S.flash,
        flashColor = S.flashColor,
    }
end

return ScreenFx
