-- Taunt: a jeer that takes a body's attention and, with it, the body. While it lasts the victim is
-- driven at whoever taunted it with its default weapon and nothing else -- it walks toward the taunter
-- if it cannot reach, and it does not get to consult its tactics, because that is what being taunted
-- means (AI.preempt, which sits above the whole rule list).
--
-- ---------------------------------------------------------------------------
-- IT BINDS THE PLAYER NOW, AND FOR YEARS IT DID NOT
-- ---------------------------------------------------------------------------
--
-- The compulsion lived entirely in models/ai.lua's planner, which runs for a unit the PLAYER is not
-- driving. So a taunt landed on a party member was a badge with a description and no rule behind it:
-- the player read "must attack the taunter", ignored it, and played the turn however they liked. Every
-- enemy taunt in the game was decorative, and nothing on the blueprint said so -- the classic shape of
-- a rule that is reported and not enforced.
--
-- THE SEIZURE LIVES HERE, in the status, not in the thing that delivered it, and it is deliberately
-- the mechanism Charm already uses one door down (data/status/status_charm.lua): stash the victim's
-- `control` and set it to "ai". `Combat.isPlayerControlled` -- a single read of that one field -- is
-- the switch the whole battle screen turns on, so one line does all of this at once:
--
--   every input handler in states/battle.lua declines the unit   (the player has lost it)
--   the update loop hands its turn to executeEnemyAction         (something else drives it)
--   AI.preempt fires before any rule list is consulted           (and drives it at the taunter)
--
-- WHAT IT IS NOT is a side change. Charm moves the body onto the charmer's side and it fights FOR
-- them; this leaves the body exactly where it stood and only decides what it swings at. A taunted
-- knight is still yours, still counted on your side, still loses you the fight if it falls. That is
-- the whole difference between the two statuses and it is why this one is cheaper.
--
-- ---------------------------------------------------------------------------
-- A TAUNT WITH NO TAUNTER TAKES NOBODY
-- ---------------------------------------------------------------------------
--
-- `taunter` is the body on the far side of the jeer, and the compulsion is meaningless without it:
-- AI.preempt reads it, finds nothing, and falls through to the ordinary rule list -- which, on a body
-- whose control has just been taken, would mean the AI cheerfully playing the player's knight for
-- three turns with no compulsion at all. Strictly worse than doing nothing. So the reins are taken
-- only when there is a live, hostile taunter to be driven at, and handed straight back when there is
-- not (see onTick).
--
-- WHICH IS WHY THE STAMP MOVED HERE TOO. Every deliverer used to set `st.taunter` by hand on the line
-- after applying -- and two of them did not: armor_crowds_due and armor_standing_debt applied this to
-- every foe around their wearer and pointed it at nobody, so the Sentinel's whole standing rule
-- redirected exactly zero blows, in a file whose own header says the point is "turning a redirect into
-- a rule". Defaulted from `ctx.applier` (which fx.applyStatus rides the caster along as), so a taunt
-- works by default and a deliverer only writes the field when it means somebody ELSE -- which is
-- precisely what ability_straw_sentry does, naming the dummy rather than the shouter. Its line still
-- wins: the default only fills a nil.
--
-- A `debuff`, so Cure clears it and the victim comes back. It carries no statBonus: the compulsion IS
-- the effect. Correctness of the release does not depend on the removal path -- Status.remove and
-- Status.cleanse both fire onExpire as the status leaves, so however the jeer ends (countdown, Cure,
-- a dispel, the taunter cut down) the control flip is undone.

-- Take the reins, if they are takeable. Called from onApply and again on every tick, because all three
-- of its refusals are conditions that can stop being true while the badge is still running.
local function hold(ctx)
    local u, st = ctx.unit, ctx.status
    -- Nobody to be driven at: the badge runs its clock and compels nothing (see the header).
    local tt = st.taunter
    if not (tt and tt.alive and tt.side and tt.side ~= u.side) then return end
    -- A REFRESH must not re-stash. The unit is already being driven, so reading its control again
    -- would record "ai" as the state to go home to and the victim would never get its turn back.
    if u._tauntControl ~= nil then return end
    -- NOT WHILE IT IS STANDING THERE MID-TURN. Flipping control out from under an open turn would
    -- hand the player's half-spent turn -- a walk already taken, a cast already aimed -- to the AI to
    -- finish, and every input handler would start declining between one click and the next. Nothing
    -- in the game can reach this today (a taunt arrives on its deliverer's turn, so the victim's is
    -- never the open one) and that is exactly why it is guarded rather than left: the first reflex or
    -- hazard that jeers during somebody else's turn would find it. The jeer is not lost -- the tick
    -- below takes the body at the next rebase, which is before its own turn comes round.
    local turn = ctx.combat and ctx.combat.turn
    if turn and turn.unit == u then return end

    u._tauntControl = u.control
    u.control = "ai"
    -- Said out loud, because a player whose knight simply starts moving on its own is owed a reason on
    -- screen. Only when it was really theirs to lose: an enemy taunted by a Shout was being driven
    -- before and is being driven now, and a line about it every time would be noise.
    if u._tauntControl == "player" then
        ctx.log("status", string.format("%s is taunted, and will not hear you.",
            (u.char and u.char.name) or "Unit"), { u, tt })
    end
end

return {
    name = "Taunt",
    abbr = "Tnt",
    description = "Taunted: driven at whoever taunted it, and taking no orders until it wears off.",
    color = { 0.811, 0.415, 0.335 }, -- badge tint (angry red)
    -- ~3 turns at Status.TICKS_PER_TURN. Unchanged from when this bound only the AI, and left that way
    -- deliberately rather than trimmed on a hunch: nothing has measured three turns as wrong, and the
    -- number is now symmetrical -- it is exactly as long as a Shout has always held an enemy. Worth
    -- watching, because it is LONGER than Charm's ten ticks while being the lesser theft; if it wants
    -- cutting, Charm's duration is the ceiling to cut it to and the reason to write down.
    duration = 15,
    debuff = true,
    onApply = function(ctx)
        -- The default stamp (see the header). Only fills a nil, so a deliverer that names its own
        -- taunter -- the straw sentry's dummy -- still overwrites this on the line after the apply.
        if ctx.status.taunter == nil then ctx.status.taunter = ctx.applier end
        hold(ctx)
    end,
    -- THE JEER DIES WITH THE JEERER. Cut the taunter down and the body it was holding comes back on
    -- the turn that matters -- the same counterplay Charm keeps (Combat.releaseCharmedBy), arrived at
    -- from the clock rather than from the death, so it also covers a taunter that merely stopped being
    -- hostile (a charmed shouter changing hands mid-jeer). The other half is the late take: a jeer
    -- that could not claim the body when it landed claims it here instead.
    onTick = function(ctx)
        local tt = ctx.status.taunter
        if not (tt and tt.alive and tt.side ~= ctx.unit.side) then ctx.expire() return end
        hold(ctx)
    end,
    -- A body that falls while taunted comes back to its owner. Statuses wind down on a corpse rather
    -- than being stripped, so without this a revived party member would stand up with its control
    -- still handed away and no status left to hand it back.
    onDeath = function(ctx) ctx.expire() end,
    onExpire = function(ctx)
        local u = ctx.unit
        if u._tauntControl ~= nil then
            u.control = u._tauntControl
            u._tauntControl = nil
        end
    end,
}
