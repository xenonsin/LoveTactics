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
-- What provokes it is declared in `counter` and checked by ctx.mayCounter (models/trait.lua), so the
-- hover preview can warn the player of this answer through the same rules that throw it.
return {
    name = "Melee Counter",
    description = "When struck in melee, strike back with your weapon. Then it must recharge.",
    magnitude = 10, -- cooldown ticks after a counter
    -- Unlike the sword's parry this one answers an answer too: it is the Riposte Blade's reflex, and
    -- the wider guard is part of what the blade costs.
    counter = { reach = "melee", answersReactions = true },
    onDamaged = function(ctx)
        if not ctx.mayCounter() then return end
        ctx.log("action", string.format("%s counters!", (ctx.unit.char and ctx.unit.char.name) or "Unit"))
        ctx.basicAttack(ctx.attacker)
        ctx.setCooldown("trait_melee_counter", ctx.def.magnitude)
    end,
}
