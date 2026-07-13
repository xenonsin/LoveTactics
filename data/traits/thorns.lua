-- Thorns: the spiked mail bites back. When the bearer survives a MELEE physical blow -- one struck
-- from an adjacent tile -- the attacker takes a share of the damage it just dealt, straight back
-- (raw-ish flat reflection through ctx.damage). A ranged or magical hit provokes nothing: you can
-- only cut a hand that reached in. `magnitude` is the reflected percentage. Fires only on a survived
-- hit (Trait.onDamaged isn't called on the killing blow), so a lethal strike is never answered.
--
-- The reflection re-enters the damage core and so could trip the attacker's own reactions; the
-- dispatch guards in models/trait.lua (unit._reacting + MAX_DEPTH) keep that from looping.
return {
    name = "Thorns",
    description = "Melee attackers take a share of the damage they deal back.",
    magnitude = 40, -- percent of the blow reflected
    onDamaged = function(ctx)
        local attacker = ctx.attacker
        if not attacker or not attacker.alive then return end
        if attacker.side == ctx.unit.side then return end -- never a friendly or self source
        local physical = false
        for _, t in ipairs(ctx.tags or {}) do if t == "physical" then physical = true break end end
        if not physical then return end -- only a physical blow is turned on the spikes
        local dist = math.abs(attacker.x - ctx.unit.x) + math.abs(attacker.y - ctx.unit.y)
        if dist ~= 1 then return end -- melee only: struck from an adjacent tile
        local reflected = math.floor((ctx.amount or 0) * ctx.def.magnitude / 100)
        if reflected < 1 then return end
        ctx.damage(attacker, reflected, { "physical" })
    end,
}
