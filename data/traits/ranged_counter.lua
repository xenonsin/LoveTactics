-- Ranged Counter: the archer's answer to a shot. When a foe strikes from RANGE -- from a tile that
-- is not adjacent -- the bearer returns fire with its default weapon, provided that weapon is itself
-- ranged and the attacker stands within its reach. Then the reflex recharges for a spell.
--
-- The mirror of melee_counter: that one answers an adjacent blow, this one answers a distant one. A
-- bearer whose default weapon is a blade (range 1) can never fire back, so this trait sits inert on a
-- melee unit -- it wants a bow. Free (no resource, no turn) and only on a survived hit.
--
-- The `counter` rule declares what provokes it -- a distant blow, answerable only with a weapon that
-- reaches back -- and ctx.mayCounter (models/trait.lua) checks it, so the hover preview can warn the
-- player of this answer through the same rules that fire it.
return {
    name = "Ranged Counter",
    description = "When shot from range, fire back with a ranged weapon. Then it must recharge.",
    magnitude = 10, -- cooldown ticks after a counter
    counter = { reach = "ranged", answersReactions = true },
    onDamaged = function(ctx)
        if not ctx.mayCounter() then return end
        ctx.log("action", string.format("%s returns fire!", (ctx.unit.char and ctx.unit.char.name) or "Unit"))
        ctx.basicAttack(ctx.attacker)
        ctx.setCooldown("ranged_counter", ctx.def.magnitude)
    end,
}
