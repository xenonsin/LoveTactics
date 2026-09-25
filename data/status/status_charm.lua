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
        local turner = ctx.applier
        -- ---------------------------------------------------------------------------
        -- A BINDING: A CHARM LANDED BY SOMEBODY ALREADY ON THE VICTIM'S SIDE
        -- ---------------------------------------------------------------------------
        --
        -- There is nothing to take. The body is already standing where the charmer is standing -- it
        -- walked onto the board hers (the succubus line's congregation, data/traits/trait_the_blooded.lua),
        -- and what the status is doing is RECORDING WHOSE IT IS rather than changing hands.
        --
        -- Without this branch the fallback below reads "a charm always changes hands" and flips the
        -- body to the far side, which for one of her own thralls means handing it to the player at the
        -- opening bell. That fallback is correct for the case it was written for -- ground charms
        -- nobody, so a sweetbriar turns its victim on its own line -- and wrong for this one, and the
        -- two are told apart by the one fact that distinguishes them: whether the turner is a foe.
        --
        -- IT STASHES NO SIDE, BECAUSE THERE IS NONE TO GO BACK TO. A bound body has no allegiance of
        -- its own left; the binding is the only reason it is on a side at all. What happens when it
        -- ends is onExpire's business, and it is not a reversion.
        --
        -- `control = "ai"` regardless: bound or taken, nobody drives a charmed body by hand.
        if turner and turner.alive and turner.side == u.side then
            if u._charmSide then return end -- taken from somewhere else already; that claim is older
            ctx.status.bound = true
            ctx.status.charmer = turner
            u.control = "ai"
            return
        end
        -- A REFRESH must not re-stash. The unit is already flipped, so reading its side again would
        -- record the charmer's side as the one to go home to and the reversion would strand it.
        if u._charmSide then return end
        u._charmSide, u._charmControl = u.side, u.control
        -- Whoever turned it, when the deliverer named itself (fx.applyStatus rides the caster along as
        -- `applier`). Ground charms nobody -- the sweetbriar has no owner to fight for -- so the
        -- fallback turns the victim on its own line, which is the same sentence from the other end.
        -- The turner's own side is used only when it really is the far side: a charm is a body
        -- changing hands, and it always changes.
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
    -- TWO ENDINGS, BECAUSE THERE WERE TWO BEGINNINGS.
    --
    -- A body that was TAKEN goes back: the stash is restored and it stands on its own side again. That
    -- is the ordinary charm, and the stash being present is what says so.
    --
    -- A body that was BOUND has no side to be put back on (see onApply). It was never anybody else's
    -- during this fight -- it walked on already hers -- so there is no allegiance to hand it. It comes
    -- back to itself and it LEAVES, which is the honest reading of a blooded soldier waking up in a
    -- room full of demons with the woman who was holding its name lying dead on the floor. Dismissed
    -- rather than killed: nothing struck it, so it leaves no corpse, feeds no death reflex, pays no
    -- spoils and cannot be raised by whatever else is watching.
    --
    -- WHICH MAKES CUTTING THE CHARMER THE WHOLE FIGHT ON THAT GROUND, which is this circle's own law
    -- (the Lust entry in models/descent.lua) finally given the largest payoff it has: fell her and the
    -- room empties, because most of the room was never fighting you on its own account.
    --
    -- The stash is checked FIRST and wins, for the one case that carries both marks: a bound thrall the
    -- PLAYER charmed away from her holds a real stash, and a body the party took should be handed back
    -- to the side it was standing on when they took it rather than walked off the board.
    onExpire = function(ctx)
        local u = ctx.unit
        -- A Consort (data/status/status_consort.lua) is a rider on the charm and leaves with it, on every
        -- ending: a body handed back must not keep the Queen's damage or her oath for one swing.
        if ctx.combat and require("models.status").has(u, "status_consort") then
            require("models.status").remove(ctx.combat, u, "status_consort")
        end
        if u._charmSide then
            u.side, u.control = u._charmSide, u._charmControl
            u._charmSide, u._charmControl = nil, nil
            return
        end
        if ctx.status.bound and u.alive then
            require("models.combat").dismiss(ctx.combat, u, string.format(
                "%s comes back to itself, and walks out.", (u.char and u.char.name) or "The bound"))
        end
    end,
}
