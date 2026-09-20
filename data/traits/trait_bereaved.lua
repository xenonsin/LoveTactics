-- BEREAVED: the sow's whole rule, and the one boss trigger in this game that the PLAYER pulls.
--
-- Every other escalation in the folder is read off the boss's own bar. trait_boss_phases fires on
-- onDamaged at a fraction of health, the Hollow Crown counts thresholds, Rising Wrath scales off what is
-- already gone -- all of them things the party makes happen by winning, which means none of them is a
-- decision. This one is: the cub is the weakest body on the board, killing it is the obvious play, and
-- killing it is what turns the mother into the thing that ends the run.
--
-- SO THE ADDS RULE RUNS BACKWARDS HERE, and that is the entire design. A player who has learned this
-- game's lesson -- clear the chaff, then the big one -- walks straight into it once. After that the
-- fight is a real question with two costed answers: eat the cub's swipes for the whole fight, or take
-- the kill and face what she does about it. Neither is free, which is what makes it a choice rather than
-- a trap with one exit.
--
-- IT CANNOT BE BURST PAST, AND THAT IS WHY IT LIVES ON A DEATH. trait_boss_phases' own header records
-- the honest hole in a health-gated stage: onDamaged dispatches in the SURVIVOR branch only, so a blow
-- that kills never crosses a threshold and a big enough burst skips the phase entirely. A rage keyed to
-- the cub has no such door. It can only be declined -- by leaving the cub alive, which costs -- and that
-- asymmetry is worth more than a second health gate.
--
-- Built on trait_engorge's shape rather than invented: onAnyDeath, a test on the fallen, a bonus and a
-- line. The differences are that it reads the fallen's BLUEPRINT (a specific animal, not any body) and
-- that it fires once ever.
--
-- THE BONUS IS BANKED, THE STATUS IS THE BADGE. ctx.addBonus is what actually moves her damage;
-- status_enraged is the thing the player can see and point at, applied at the same magnitude so the two
-- never disagree. This is exactly how trait_boss_phases' `enrage` response pairs them, and the status's
-- own description ("worse the nearer it is to death") is already written for a body in this state.
return {
    name = "Bereaved",
    description = "If her cub falls, she stops keeping anything back.",
    -- WHOSE DEATH. An id rather than "any ally", because a sow fielded beside road filler must not be set
    -- off by the filler: the fight's whole decision is about ONE body, and a rage that any corpse could
    -- trigger would hand the player the escalation for free on a turn they were not choosing anything.
    cub = "character_bear",
    -- +10 Damage, against her authored 22. Priced as not quite half again: enough that the back half of
    -- the fight is visibly a different animal, and short of the doubling that would make killing the cub
    -- simply wrong rather than expensive. Both roads have to stay walkable or the choice collapses. This
    -- is the first number to measure through models/autobattle.lua and the likeliest to move.
    damage = 10,
    onAnyDeath = function(ctx)
        local fallen, u = ctx.fallen, ctx.unit
        if not (fallen and u and u.alive) then return end
        if fallen == u then return end
        if fallen.side ~= u.side then return end -- your dead are not her loss
        if not (fallen.char and fallen.char.id == ctx.def.cub) then return end
        if (ctx.trait.stacks or 0) > 0 then return end -- once. A second cub does not double her.
        ctx.trait.stacks = 1
        ctx.addBonus("damage", ctx.def.damage)
        ctx.applyStatus(u, "status_enraged", { magnitude = ctx.def.damage })
        ctx.log("action", string.format("%s stops keeping anything back.",
            (u.char and u.char.name) or "She"))
    end,
}
