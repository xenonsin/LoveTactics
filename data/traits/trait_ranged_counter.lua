-- Ranged Counter: the archer's answer to a shot. When a foe strikes from a tile the bearer's bow can
-- cover, the bearer returns fire.
--
-- Under the reach rule this needs no special casing at all: it declares no `reach`, so it answers
-- whatever a weapon in the grid can reach back at, and Combat.answeringWeapon does the rest. On an
-- archer that means the bow's band -- and NOT the tile right in front of them, because a bow's
-- `minRange` dead zone bars the point-blank answer. Closing on an archer is how you shut its counter
-- off; that is the rule this whole system is built to make visible.
--
-- Free of the timeline (no turn spent) but not of the pool: priced as a swing by Trait.answerCost, so
-- returning fire costs what firing costs, doubled for each answer already thrown this round. Only on a
-- survived hit.
return {
    name = "Ranged Counter",
    description = "When shot from range, spend a shot's stamina to fire back.",
    counter = { answersReactions = true },
    onDamaged = function(ctx)
        if not ctx.mayCounter() then return end
        if not ctx.pay() then return end
        ctx.log("action", string.format("%s returns fire!", (ctx.unit.char and ctx.unit.char.name) or "Unit"))
        ctx.basicAttack(ctx.attacker)
    end,
}
