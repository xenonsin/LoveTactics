-- Parry: the sword's answer, and the sword archetype's defining trait (docs/weapons.md). A swordsman
-- struck from an adjacent tile turns the blow aside and cuts back with its own weapon -- costing a
-- little stamina but none of the timeline -- then needs a long moment to recover the guard.
--
-- Priced like every triggered reflex in the game (see payCost in models/trait.lua): a cooldown paces
-- the answers within an exchange, and the stamina bounds them across the battle. Cheapest of the three,
-- because it is the one every recruit's iron sword carries and the reference the melee kit is tuned
-- against -- a swordsman who is swarmed still answers most of it, they just cannot also swing all day.
--
-- Deliberately the slow half of a pair with data/traits/melee_counter.lua, which is otherwise the same
-- reflex: melee_counter recharges in 10 ticks, this in 20. A sword carries one or the other, never
-- both -- an ordinary blade parries, and the Riposte Blade (data/items/weapon/weapon_riposte_blade.lua)
-- swaps this out for melee_counter, which is exactly what its price buys: the sword whose parry is a
-- true riposte, answering twice as often.
--
-- The cooldown key is this trait's own id, so a unit that somehow ends up with both (a Riposte Blade
-- in one hand and an iron sword in the grid) holds two independent timers and answers on either. That
-- is a deliberate reward for building a duelist, not a bug -- but no single weapon grants both.
return {
    name = "Parry",
    description = "When struck in melee, spend stamina to turn the blow and cut back. Then recover your guard.",
    magnitude = 20,                          -- cooldown ticks after a parry (melee_counter's is 10)
    cost = { stat = "stamina", amount = 4 }, -- paid per parry; no stamina, no answer
    -- What provokes it, checked by ctx.mayCounter (models/trait.lua) -- and read by the hover preview,
    -- so the player is warned of this answer through the same rules that throw it. A parry answers an
    -- ATTACK, never another answer (no answersReactions): "did they swing at me, or were they only
    -- answering me?" Without that every sword exchange becomes a three-hit volley -- strike, counter,
    -- counter-back -- since both the knight and the common bandit carry an iron sword. One counter per
    -- attack; the trade stays legible.
    counter = { reach = "melee" },
    onDamaged = function(ctx)
        if not ctx.mayCounter() then return end
        -- The one gate that spends anything, so it comes after every free refusal above: an exhausted
        -- swordsman simply eats the blow, and a parry that declines is never billed for it.
        if not ctx.pay() then return end
        ctx.log("action", string.format("%s parries!", (ctx.unit.char and ctx.unit.char.name) or "Unit"))
        ctx.basicAttack(ctx.attacker)
        ctx.setCooldown("trait_parry", ctx.def.magnitude)
    end,
}
