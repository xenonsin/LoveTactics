-- Parry: the sword's answer, and the sword archetype's defining trait (docs/weapons.md). A swordsman
-- struck from an adjacent tile turns the blow aside and cuts back with its own weapon, free -- no
-- resource, no turn -- then needs a long moment to recover the guard.
--
-- Deliberately the slow half of a pair with data/traits/melee_counter.lua, which is otherwise the same
-- reflex: melee_counter recharges in 10 ticks, this in 20. A sword carries one or the other, never
-- both -- an ordinary blade parries, and the Riposte Blade (data/items/weapon/riposte_blade.lua)
-- swaps this out for melee_counter, which is exactly what its price buys: the sword whose parry is a
-- true riposte, answering twice as often.
--
-- The cooldown key is this trait's own id, so a unit that somehow ends up with both (a Riposte Blade
-- in one hand and an iron sword in the grid) holds two independent timers and answers on either. That
-- is a deliberate reward for building a duelist, not a bug -- but no single weapon grants both.
return {
    name = "Parry",
    description = "When struck in melee, turn the blow and cut back. Then recover your guard.",
    magnitude = 20, -- cooldown ticks after a parry (melee_counter's is 10)
    onDamaged = function(ctx)
        local attacker = ctx.attacker
        if not attacker or not attacker.alive then return end
        if attacker.side == ctx.unit.side then return end -- never answer a friendly or self source
        if ctx.onCooldown("parry") then return end
        local dist = math.abs(attacker.x - ctx.unit.x) + math.abs(attacker.y - ctx.unit.y)
        if dist ~= 1 then return end -- melee only: an archer stood too far to be answered in kind
        -- A parry answers an ATTACK, never another answer: "did they swing at me, or were they only
        -- answering me?" (Trait.isReacting). Without it every sword exchange in the game becomes a
        -- three-hit volley -- strike, counter, counter-back -- since both the knight and the common
        -- bandit carry an iron sword. One counter per attack; the trade stays legible.
        if ctx.isReacting(attacker) then return end
        ctx.log("action", string.format("%s parries!", (ctx.unit.char and ctx.unit.char.name) or "Unit"))
        ctx.basicAttack(attacker)
        ctx.setCooldown("parry", ctx.def.magnitude)
    end,
}
