-- Shield Shove: the guard answers with the boss of the shield rather than the edge of a sword. A melee
-- attacker that lands a blow is driven two tiles straight back, and pays for whatever it slams into on
-- the way.
--
-- Read it beside Shield Bash (data/traits/trait_shield_bash.lua), which is the same instinct one step
-- further along. The Bash needs the bearer to be BRACED (`requiresStatus = "status_defending"`) and
-- lands a Stun; this needs nothing but a foe in your face, and lands a foot of ground. That is the
-- trade, and it is the knight's own trade restated: the Bash is worth more when you saw it coming, and
-- this is worth something when you did not.
--
-- `shoves` is what tells the rest of the machinery that this reflex is NOT a swing (models/trait.lua):
-- there is no weapon in the motion, so it is billed the stamina it declares here rather than a
-- sword's price, and the hover preview names it without promising damage. It deals nothing by itself
-- -- the wall, the fire, the spike trap and the drop do the talking, exactly as a mace's shove does.
--
-- `answersReactions = true`: a shield does not care whether the arm that reached in was attacking or
-- answering. It is the cheapest reflex on the shelf and the least discriminating, and those two facts
-- are the same fact.
--
-- No cooldown. The escalating answer price (each answer this round costs double the last -- see
-- Trait.answerCost) is what paces it, so a knight in a doorway shoves the first foe for 5, the second
-- for 10, the third for 20, and then is simply a knight in a doorway.
return {
    name = "Shield Shove",
    description = "Melee attackers are driven two tiles back. A collision hurts them.",
    cost = { stat = "stamina", amount = 5 },
    counter = { reach = "melee", requiresTag = "physical", answersReactions = true, shoves = 2 },
    onDamaged = function(ctx)
        if not ctx.mayCounter() then return end
        if not ctx.pay() then return end
        ctx.knockback(ctx.attacker, ctx.def.counter.shoves)
        ctx.log("action", string.format("%s drives %s back with the shield!",
            (ctx.unit.char and ctx.unit.char.name) or "Unit",
            (ctx.attacker.char and ctx.attacker.char.name) or "the attacker"))
    end,
}
