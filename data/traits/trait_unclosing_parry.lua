-- Unclosing Parry: The Unclosing Edge's answer. It turns the blow and opens a wound that will not shut
-- (status_unclosing_wound) rather than cutting back -- no damage at all, and the victim can no longer be
-- healed by any means for the window it holds.
--
-- The reason it is worth a slot: every other sword in the game answers with a number, and a number is
-- something a healer can undo. This one answers by taking the healer out of the fight for that body. It
-- does nothing whatsoever to a foe nobody was going to mend, and it is the whole battle against one that
-- was -- which makes it a read on the enemy roster rather than on the exchange in front of you.
--
-- `applies` and no swing, for the same reason data/traits/trait_binding_parry.lua declares it: the hover
-- preview quotes either a damage number or a status name, and a reflex doing both would misreport one.
return {
    name = "Unclosing Parry",
    description = "When struck by a foe your blade can reach, spend a swing's stamina to open a wound that cannot be healed.",
    counter = { applies = "status_unclosing_wound" },
    onDamaged = function(ctx)
        if not ctx.mayCounter() then return end
        if not ctx.pay() then return end
        ctx.applyStatus(ctx.attacker, "status_unclosing_wound")
        ctx.log("action", string.format("%s opens a wound on %s that will not close!",
            (ctx.unit.char and ctx.unit.char.name) or "Unit",
            (ctx.attacker.char and ctx.attacker.char.name) or "the attacker"))
    end,
}
