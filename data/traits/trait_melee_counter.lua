-- Melee Counter: a brawler's reflex. When a foe lands a blow from an adjacent tile the bearer hits
-- straight back with whatever weapon reaches. A shot from range provokes nothing -- this one is
-- adjacent by its nature, so it declares `reach = "melee"` rather than taking the default "answer
-- anything you can reach back at".
--
-- "Melee" is read from where the attacker stood at the moment of the hit. The counter re-enters the
-- damage core and can trip the target's OWN counter, which the dispatch guards in models/trait.lua
-- (unit._reacting + MAX_DEPTH) keep from looping.
--
-- The reaction only fires on a SURVIVED hit (Trait.onDamaged is not called on the blow that kills), so
-- a lethal strike is never answered. What provokes it is declared in `counter` and checked by
-- ctx.mayCounter, so the hover preview can warn the player of this answer through the same rules that
-- throw it. Priced as a swing by Trait.answerCost, like every answer -- see data/traits/trait_parry.lua.
return {
    name = "Melee Counter",
    description = "When struck in melee, spend a swing's stamina to strike back with your weapon.",
    -- Unlike the sword's parry this one answers an answer too: the wider guard is part of what the
    -- items carrying it cost.
    counter = { reach = "melee", answersReactions = true },
    onDamaged = function(ctx)
        if not ctx.mayCounter() then return end
        if not ctx.pay() then return end
        ctx.log("action", string.format("%s counters!", (ctx.unit.char and ctx.unit.char.name) or "Unit"))
        ctx.basicAttack(ctx.attacker)
    end,
}
