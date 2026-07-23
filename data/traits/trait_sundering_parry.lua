-- Sundering Parry: Sunderer's Answer's reflex, and the anti-reflex reflex. It turns the blow and leaves
-- the attacker Sundered (status_sundered) -- every trait, guard and reflex that body carries falls silent
-- for the window, which includes whatever it was about to answer this sword with.
--
-- Its place in the kit is the exchange between two armoured answerers, which is otherwise the most
-- attritional shape a fight in this game takes: both sides carry counters, both pay escalating stamina to
-- throw them, and nothing resolves. This ends that by unplugging one side of it. It is close to useless
-- against a beast with no traits at all -- read the enemy before you carry it.
--
-- Deliberately NOT a damage reflex: sundering a champion for a window is worth more than any single swing
-- in the game, and pairing the two would make it strictly better than the sword it is measured against.
-- `applies` also keeps the preview honest (see data/traits/trait_binding_parry.lua).
return {
    name = "Sundering Parry",
    description = "When struck by a foe your blade can reach, spend a swing's stamina to silence every trait and reflex they carry.",
    counter = { applies = "status_sundered" },
    onDamaged = function(ctx)
        if not ctx.mayCounter() then return end
        if not ctx.pay() then return end
        ctx.applyStatus(ctx.attacker, "status_sundered")
        ctx.log("action", string.format("%s sunders %s's guard!",
            (ctx.unit.char and ctx.unit.char.name) or "Unit",
            (ctx.attacker.char and ctx.attacker.char.name) or "the attacker"))
    end,
}
