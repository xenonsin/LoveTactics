-- Charm: the victim fights for whoever charmed it -- an uncontrollable ally on the charmer's side for
-- the duration, planned by the enemy AI (Combat.planEnemyAction reads unit.side), then it reverts.
--
-- THE FLIP LIVES HERE, in the status, not in the thing that delivered it. It used to live in the Charm
-- ability's effect, and every OTHER deliverer applied this status and flipped nothing: the sweetbriar
-- underfoot (data/hazards/hazard_sweetbriar.lua), the Petal Drift's touch, the Hartwood Bride's
-- antlers, the Chorister's Lure. Those four are precisely the ones that charm the PLAYER -- so a party
-- member walked out of the whole Lust circle wearing a magenta badge and still taking the player's
-- orders, and the one control mechanic that circle is built on did nothing at all. A status that IS a
-- change of allegiance owns that change, or the next deliverer forgets it too. Only the landing ROLL
-- stayed with the ability, because that is a fact about the spell (it rewards softening a victim
-- first) rather than about being charmed.
--
-- IT ENDS WITH WHOEVER CAST IT. The status remembers the body that turned it (`charmer`, stamped
-- below beside the flip), and Combat.releaseCharmedBy hands back everyone that body was holding the
-- moment it leaves the field -- felled, or dismissed. Cutting down the singer is the counterplay this
-- circle is meant to be read as, and a charm that outlived its charmer took that away: killing the
-- Chorister bought nothing on the turn it mattered, and left a party member swinging at their own line
-- on behalf of a corpse. Ground is the one charm nobody holds (see the turner fallback below), so a
-- briar's charm answers to no death and simply runs its short clock.
--
-- A quest objective is not taken: `bossProof` refuses this outright on a `boss` body, which is what
-- every general and mark in the game leans on (see Status.isImmune). That gate moved here with the
-- flip, for the same reason -- the briar cannot be asked to remember it.
--
-- A `debuff`, so Cure/Panacea can break the spell and free the victim early -- the fair counterplay
-- (an ally on the charmed unit's former side snaps it out of it). Correctness of the reversion no
-- longer depends on the removal path: Status.remove and Status.cleanse both fire onExpire as the
-- status leaves, so however Charm ends -- countdown, Cure, or a dispel -- the side/control flip is
-- undone and the unit returns to the side it started on.
return {
    name = "Charm",
    abbr = "Chm",
    description = "Charmed: fights for the enemy that turned it, until it comes to its senses.",
    color = { 0.837, 0.469, 0.755 }, -- badge tint (magenta)
    duration = 10, -- ~2 turns at Status.TICKS_PER_TURN: long enough for the victim to actually act
    debuff = true,
    bossProof = true, -- a quest objective is never turned (Status.isImmune)
    -- It STAYS when the bearer walks off the ground that laid it. Every other zone-granted status this
    -- flag governs is a condition of standing somewhere; an allegiance is not. Zone-bound, a body
    -- charmed by the sweetbriar would be driven by the enemy AI for exactly as long as its own turn
    -- kept it on the flowers -- and would snap back to the party mid-walk, halfway through an action
    -- aimed at its own line. It carries the charm away with it and counts it down like anything else.
    lingers = true,
    -- Take the body: stash the side and command it came in on, then move it onto the charmer's.
    -- `control = "ai"` is the "uncontrollable" half -- turned or not, nobody is driving it by hand.
    onApply = function(ctx)
        local u = ctx.unit
        -- A REFRESH must not re-stash. The unit is already flipped, so reading its side again would
        -- record the charmer's side as the one to go home to and the reversion would strand it.
        if u._charmSide then return end
        u._charmSide, u._charmControl = u.side, u.control
        -- Whoever turned it, when the deliverer named itself (fx.applyStatus rides the caster along as
        -- `applier`). Ground charms nobody -- the sweetbriar has no owner to fight for -- so the
        -- fallback turns the victim on its own line, which is the same sentence from the other end.
        -- The turner's own side is used only when it really is the far side: a charm is a body
        -- changing hands, and it always changes.
        local turner = ctx.applier
        local takes = (turner and turner.side ~= u.side and turner.side)
            or ((u.side == "party") and "enemy" or "party")
        u.side, u.control = takes, "ai"
        -- ...and WHO is holding it, on the status instance -- the same shape Shout stamps a Taunt's
        -- `.taunter` in, and read back by the same helper (Status.removePointingAt). Stamped here,
        -- inside the take, rather than on every application: a refresh returns above without
        -- re-stashing, so the body keeps answering to the one whose side it is actually standing on
        -- instead of to whoever last topped the duration up. Nil for ground, which holds nobody.
        ctx.status.charmer = turner
    end,
    -- A body that falls while charmed comes home. Statuses wind down on a corpse rather than being
    -- stripped, so without this the fight can end with one of your own lying on the enemy's side --
    -- and Combat.reviveFallenParty, which reads `side == "party"` to decide who is carried out of a won
    -- fight, would leave them on the floor for good. Expiring here runs the ordinary reversion below.
    onDeath = function(ctx) ctx.expire() end,
    onExpire = function(ctx)
        local u = ctx.unit
        if u._charmSide then
            u.side, u.control = u._charmSide, u._charmControl
            u._charmSide, u._charmControl = nil, nil
        end
    end,
}
