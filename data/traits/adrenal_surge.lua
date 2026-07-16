-- Adrenal Surge: every blow that lands on the bearer pulls their next turn CLOSER. Being hit lowers
-- initiative (lower acts sooner -- see Combat.initiative), so a fighter under fire comes back around
-- faster and faster.
--
-- The fighter's answer to the shape of its own problem. A fighter has to walk into range, and the walk
-- is paid for in the currency it can least afford: initiative. Everything that shoots it on the way in
-- is buying tempo off it. This inverts the exchange -- the beating IS the approach. Focus a fighter
-- wearing this and you are winding it up.
--
-- Priced with a cooldown rather than a resource, and that is the deliberate choice: a per-hit surge with
-- no gate would make being surrounded strictly optimal, and a fighter facing three foes would take three
-- surges a round and act continuously. The cooldown means it answers the FIRST blow of an exchange and
-- not the flurry -- so the reward is for being engaged, not for being mobbed, and one big hit is worth
-- exactly as much to it as one small one.
--
-- Fires from onDamaged, so it reads a survivor and a real, post-mitigation hit. It is not suppressed by
-- Stun or Frozen the way a counter is -- Trait.onDamaged gates those, so a stunned fighter's surge does
-- not fire, which is correct: this is a reflex, and hard control is precisely the thing that takes your
-- reflexes away.
return {
    name = "Adrenal Surge",
    description = "Taking a hit pulls your next turn sooner. The beating is the approach.",
    magnitude = 3,  -- initiative pulled off the bearer's next turn, per firing
    cooldown = 5,   -- ticks before another blow can surge it again
    onDamaged = function(ctx)
        if ctx.onCooldown(ctx.trait.id) then return end
        ctx.setCooldown(ctx.trait.id, ctx.def.cooldown or 0)
        local u = ctx.unit
        -- Never past its own slot: initiative 0 is "acting now", and a unit shoved below it would be
        -- scheduled in the past -- Combat.rebase floors the field at the fastest unit, so a negative
        -- here would quietly drag the whole order around it rather than moving this fighter up.
        local pull = math.min(ctx.def.magnitude or 0, u.initiative)
        if pull <= 0 then return end
        u.initiative = u.initiative - pull
        ctx.log("action", string.format("%s's blood is up -- it moves sooner!",
            (u.char and u.char.name) or "Unit"))
    end,
}
