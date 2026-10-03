-- GORGON'S BLOOD: in Ovid, Medusa's blood fell on the Libyan desert as snakes. A slashing blow that cuts the
-- bearer makes an adder spring up beside it (models/gorgon.lua's Gorgon.blood, to four at once). Carried by
-- Medusa's organ and by Serpent Locks, the poisoner's coat she drops -- one rule, both sides of the fight.
--
-- `notAReaction`: it is blood, not a reflex, so a stunned bearer still bleeds snakes.
return {
    name = "Gorgon's Blood",
    description = "When a slashing blow strikes it, an adder springs up beside it.",
    notAReaction = true,
    onDamaged = function(ctx)
        require("models.gorgon").blood(ctx.combat, ctx.unit, ctx.tags, ctx.amount)
    end,
}
