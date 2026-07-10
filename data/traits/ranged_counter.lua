-- Ranged Counter: the archer's answer to a shot. When a foe strikes from RANGE -- from a tile that
-- is not adjacent -- the bearer returns fire with its default weapon, provided that weapon is itself
-- ranged and the attacker stands within its reach. Then the reflex recharges for a spell.
--
-- The mirror of melee_counter: that one answers an adjacent blow, this one answers a distant one. A
-- bearer whose default weapon is a blade (range 1) can never fire back, so this trait sits inert on a
-- melee unit -- it wants a bow. Free (no resource, no turn) and only on a survived hit.
return {
    name = "Ranged Counter",
    description = "When shot from range, fire back with a ranged weapon. Then it must recharge.",
    magnitude = 10, -- cooldown ticks after a counter
    onDamaged = function(ctx)
        local attacker = ctx.attacker
        if not attacker or not attacker.alive then return end
        if attacker.side == ctx.unit.side then return end
        if ctx.onCooldown("ranged_counter") then return end
        local dist = math.abs(attacker.x - ctx.unit.x) + math.abs(attacker.y - ctx.unit.y)
        if dist <= 1 then return end -- ranged only: an adjacent blow is melee_counter's business
        local range = ctx.weaponRange()
        if range <= 1 then return end -- needs a ranged default weapon to answer at all
        if dist > range then return end -- the attacker shot from beyond our own reach
        ctx.log("action", string.format("%s returns fire!", (ctx.unit.char and ctx.unit.char.name) or "Unit"))
        ctx.basicAttack(attacker)
        ctx.setCooldown("ranged_counter", ctx.def.magnitude)
    end,
}
