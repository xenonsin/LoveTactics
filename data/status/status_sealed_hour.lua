-- Sealed Hour: for a little while, nothing that happens to this body actually happens to it. Every
-- point of damage and every point of mending aimed at the bearer is BANKED (Status.defer) instead of
-- landing, and the whole ledger settles as one number the moment the hour is up.
--
-- Both funnels honour it -- Combat.dealFlatDamage and Combat.applyHeal -- and that symmetry is the
-- entire design. A ward that only held damage would be a strictly better barrier. Holding the healing
-- too is what makes it a BARGAIN: you cannot be killed under it, and you cannot be saved under it
-- either, so sealing an ally at 4 health is not a rescue -- it is a promise to rescue them, and you
-- still have to keep it before the hour runs out.
--
-- What it actually buys is TIME, which is the one thing a tactics game can never buy any other way.
-- The target cannot fall while three enemies spend their turns on it, and every point they spend is
-- still owed -- so the seal is a wager that your side can use those turns better than theirs can. Lose
-- the wager and the ledger kills them anyway, on the priest's own clock.
--
-- A net-NEGATIVE ledger mends, which is the payoff for winning the wager: mending poured in during the
-- hour lands all at once at the end, and lands whole even if the target "died" three times over on the
-- way. This is the only place in the game where healing a full-health unit is not waste.
return {
    name = "Sealed Hour",
    abbr = "Hour",
    description = "Sealed: all damage and healing is held, then settles at once when it ends.",
    color = { 0.92, 0.88, 0.98 }, -- badge tint (suspended pale violet)
    duration = 12,                -- ~2.5 turns of held time
    defers = true,
    onExpire = function(ctx)
        local owed = ctx.status.ledger or 0
        if owed == 0 then return end
        if owed > 0 then
            ctx.log("status", string.format("%s's sealed hour comes due: %d.",
                (ctx.unit.char and ctx.unit.char.name) or "Unit", owed), ctx.unit)
            -- Raw, and deliberately: armor already had its say when each blow was banked (the ledger
            -- holds MITIGATED damage -- see Combat.dealFlatDamage). Charging it again here would ward
            -- the target twice for one seal and quietly make the spell a damage reduction, which is
            -- the one thing it is not.
            ctx.damage(ctx.unit, owed, nil, { raw = true })
        else
            ctx.heal(ctx.unit, -owed)
            ctx.log("status", string.format("%s's sealed hour resolves in mending: %d.",
                (ctx.unit.char and ctx.unit.char.name) or "Unit", -owed), ctx.unit)
        end
    end,
}
