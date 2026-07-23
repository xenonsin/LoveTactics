-- Spiteful Ichor: the bearer's blood is the weapon. A melee attacker that draws it is Poisoned for
-- the trouble -- no swing, no shove, no cost at all.
--
-- The reactive half of the Crucible's vocabulary. Envenom (data/items/consumable/consumable_envenom.lua)
-- poisons what YOU hit; this poisons what hits you, and between them the alchemist finally has an
-- answer to being reached. Nothing on that shelf wanted to be in melee and nothing on it could stop
-- being: this does not stop it either, it just makes closing the distance a purchase.
--
-- Free, uncooled, and it answers an answer (`answersReactions`), which puts it in the same bracket as
-- Thorns (data/traits/trait_thorns.lua) -- and for the same stated reason: a body that is simply
-- CAUSTIC holds no guard to be worn down, so there is nothing to price and nothing to recharge. What
-- keeps it honest is that Poison is slow. A foe that eats three stacks of it has bought three turns of
-- rot it will feel later, which is exactly the tempo the alchemist trades in.
--
-- `requiresTag = "physical"` and `reach = "melee"`: you cannot be splashed by an arrow, and a spell
-- never touched you.
return {
    name = "Spiteful Ichor",
    description = "Melee attackers are Poisoned by the blood they draw.",
    counter = { reach = "melee", requiresTag = "physical", answersReactions = true,
                applies = "status_poison" },
    onDamaged = function(ctx)
        if not ctx.mayCounter() then return end
        ctx.applyStatus(ctx.attacker, "status_poison")
        ctx.log("action", string.format("%s's blood scalds %s.",
            (ctx.unit.char and ctx.unit.char.name) or "Unit",
            (ctx.attacker.char and ctx.attacker.char.name) or "the attacker"))
    end,
}
