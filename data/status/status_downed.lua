-- Downed: a body on the ground with a clock over it. When a real, revivable unit falls it is not gone
-- and it is not yet a corpse either -- killUnit lays it down INCAPACITATED (`incapacitated`), and this
-- status rides that body as the WINDOW in which the same character can still be brought back to its
-- feet (Combat.reanimate: the Revive spell, the revive scroll, Reviving Salts, a Phoenix Down). While
-- the window is open the body is NOT a corpse, so nothing that reads the dead -- Raise Dead, Corpse
-- Burst, the Ledger's Due -- can touch it. Let the window close and the body TURNS TO A CORPSE: past
-- reviving for the rest of this battle, but now a real body the necromancer's shelf can feed on. It is
-- the FFT downed-count, and like status_knell the whole design is about making the deadline fair to
-- look at.
--
-- THE COUNT IS PLAIN `duration`, so the badge wears the hourglass like every other clock in the UI
-- (ui/glyphs.lua) and what you see is what you have: a party looking at a number and deciding whether
-- a turn spent reaching the body is worth more than a turn spent killing. A death sentence whose clock
-- is invisible is a rug pull; this one is legible to the tile.
--
-- THE WINDOW CLOSES FROM onExpire, and here that is correct where status_knell went out of its way to
-- avoid it. Knell fires from onTick because onExpire also runs on a Cure, and a countdown that killed
-- on the cure would kill on the save. This is the mirror case:
--   * The bearer is already DEAD, so onTick never runs on it at all -- Status.tick gates onTick on
--     `unit.alive`, while still AGEING statuses on the fallen and firing onExpire at zero. onTick is
--     simply not available to an incapacitated body; onExpire is the only hook that fires. And nothing
--     can spend the body before the window closes (necromancy reads `corpse`, which is not set yet), so
--     onExpire always finds it still incapacitated and waiting.
--   * The one non-expiry removal path -- a successful revive -- does `body.statuses = {}` DIRECTLY
--     (Combat.reanimate / reviveFallenParty), which bypasses Status.remove and so never fires onExpire.
--     A save cleanly cancels the clock; only the clock actually running out turns the body to a corpse.
-- And it is deliberately NOT a `debuff`, so Cure / Panacea can't strip it (reviving is not curing) and
-- so cleanse can never mis-fire the teardown the way it could on Knell.
--
-- `lingers`, for symmetry with the rest: there is no ground to step off -- the appointment is with the
-- body where it lies.
return {
    name = "Downed",
    abbr = "KO",
    description = "Fallen but not gone: revive before the count runs out, or the body goes cold for this battle.",
    color = { 0.603, 0.629, 0.689 }, -- badge tint (a pale, draining grey-blue -- a body going cold)
    duration = 15, -- ~3 turns at Status.TICKS_PER_TURN: FFT's three-count, long enough to reach, short enough to fear
    lingers = true, -- the appointment is with the body, not the tile
    -- The death already logged "X is defeated!" and played its own cue; this rides the body quietly,
    -- and writes its own line below when the window actually closes -- so suppress the generic
    -- "afflicted with / wears off" chatter that would otherwise bracket a fallen unit.
    hideLog = true,
    onExpire = function(ctx)
        -- The window ran out: the incapacitated body TURNS TO A CORPSE -- no longer revivable, now a
        -- harvestable body the necromancer's shelf can read. Guard defensively: a revived body wiped its
        -- statuses (so this never fires) and nothing else can clear `incapacitated`, so it should always
        -- still be set here.
        if not ctx.unit.incapacitated then return end
        ctx.unit.incapacitated = false
        ctx.unit.corpse = true
        ctx.log("death", string.format("%s's body goes cold.",
            (ctx.unit.char and ctx.unit.char.name) or "The body"), ctx.unit)
    end,
}
