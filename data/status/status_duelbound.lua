-- Duelbound: two fighters are bound to the ground they are standing on and to each other. Neither may
-- walk away (`blocksMove`); both may still swing, answer, and be helped or hindered by everyone else.
-- Whoever is still standing when the binding lifts keeps something of the one who isn't.
--
-- WHAT IT ACTUALLY DOES, mechanically, is take movement away from both of them -- and that is a far
-- more interesting thing to do to a fight than it sounds, because the two are almost never equally
-- happy about it. Binding a skirmisher to your knight is a prison. Binding your knight to their mage
-- is an execution. The spell does not decide which; the tiles you were standing on when you cast it
-- already did.
--
-- `ctx.status.opponent` is stamped onto the instance by the ability that applies it (fx.applyStatus
-- hands the effect the live instance back, so the two bindings can point at each other). onExpire is
-- the settlement, and it fires on every removal path -- a natural countdown, a Cure, a dispel -- which
-- is what keeps the reward honest: you get the boon if and only if the other one is down when your
-- binding ends, however it ended.
--
-- The boon is permanent for the battle and small on purpose. `ctx` has no addBonus of its own (that is
-- a trait's helper), so it is written straight onto `unit.bonus` -- the per-unit table
-- applyUnitPassives builds, never the shared character instance, so a duel won in the arena does not
-- follow anybody home. See the same note on the trait ctx's addBonus in models/trait.lua.
return {
    name = "Duelbound",
    abbr = "Duel",
    description = "Duelbound: cannot move -- and the survivor keeps something of the other.",
    color = { 0.86, 0.62, 0.24 }, -- badge tint (challenge amber)
    duration = 15,                -- ~3 turns to settle it
    magnitude = 3,                -- the damage the survivor keeps
    debuff = true,
    resistible = "physical",
    blocksMove = true,
    onExpire = function(ctx)
        local other = ctx.status.opponent
        -- Won only by OUTLIVING, never by killing: a duel settled by somebody else's arrow still pays
        -- the survivor, because what the binding measured was who was left standing in it. That is also
        -- what stops the spell from being a strictly better execute -- it rewards holding ground, and
        -- holding ground is a thing a whole team can help you do.
        if not (other and not other.alive) then return end
        if not ctx.unit.alive then return end
        ctx.unit.bonus = ctx.unit.bonus or {}
        local gain = ctx.magnitude or 3
        ctx.unit.bonus.damage = (ctx.unit.bonus.damage or 0) + gain
        ctx.log("status", string.format("%s wins the duel, and keeps it (+%d damage).",
            (ctx.unit.char and ctx.unit.char.name) or "Unit", gain), ctx.unit)
    end,
}
