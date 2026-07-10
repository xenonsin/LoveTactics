-- Melee Counter: a fighter's reflex. When a foe lands a MELEE blow -- one struck from an adjacent
-- tile -- the bearer hits straight back with its default weapon, then the reflex goes on cooldown
-- for a spell. A ranged shot provokes nothing (the striker stood too far to answer in kind); the
-- counter itself is free (no resource, no turn), so it retaliates without paying a cast's price.
--
-- "Melee" is read from where the attacker stood at the moment of the hit: adjacent = melee. The
-- counter re-enters the damage core and can trip the target's OWN counter, which the dispatch
-- guards in models/trait.lua (unit._reacting + MAX_DEPTH) keep from looping.
--
-- `magnitude` is the cooldown length in ticks. The reaction only fires on a SURVIVED hit
-- (Trait.onDamaged is not called on the blow that kills), so a lethal strike is never answered.
return {
    name = "Melee Counter",
    description = "When struck in melee, strike back with your weapon. Then it must recharge.",
    magnitude = 10, -- cooldown ticks after a counter
    onDamaged = function(ctx)
        local attacker = ctx.attacker
        if not attacker or not attacker.alive then return end
        if attacker.side == ctx.unit.side then return end -- never counter a friendly or self source
        if ctx.onCooldown("melee_counter") then return end
        local dist = math.abs(attacker.x - ctx.unit.x) + math.abs(attacker.y - ctx.unit.y)
        if dist ~= 1 then return end -- melee only: the attacker struck from an adjacent tile
        ctx.log("action", string.format("%s counters!", (ctx.unit.char and ctx.unit.char.name) or "Unit"))
        ctx.basicAttack(attacker)
        ctx.setCooldown("melee_counter", ctx.def.magnitude)
    end,
}
