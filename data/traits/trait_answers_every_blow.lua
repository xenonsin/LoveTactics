-- ANSWERS EVERY BLOW: the Griffin bites back at every melee blow it takes, however many there are, for half
-- its Damage. Heroes of Might and Magic's griffins are remembered for exactly this -- unlimited
-- retaliation -- and it was approved on review (2026-09-23) from five candidates drawn from other games.
--
-- FREE AND UNESCALATING, which is what "every" means: a Melee Counter pays a swing's stamina and its
-- price doubles with each answer in an exchange (Trait.answerCost); this one never calls ctx.pay. So a
-- company cannot simply surround it and pile in. Reach it with a polearm or a bow, or send in the body
-- that can take the bites.
--
-- The bite is a flat blow rather than a weapon swing, so it cannot carry the Beak and Claw's Bleed or be
-- answered in turn -- ctx.mayCounter already refuses to answer an answer.
return {
    name = "Answers Every Blow",
    description = "Bites back at every melee blow it takes for half its damage, however many come.",
    counter = { reach = "melee" },
    share = 0.5,
    onDamaged = function(ctx)
        if not ctx.attacker or not ctx.attacker.alive then return end
        if not ctx.mayCounter() then return end
        local Combat = require("models.combat")
        local amount = math.max(1, math.floor(Combat.flatStat(ctx.unit, "damage") * ctx.param("share", 0.5) + 0.5))
        ctx.log("action", string.format("%s bites back!", (ctx.unit.char and ctx.unit.char.name) or "It"),
            { ctx.unit, ctx.attacker })
        ctx.damage(ctx.attacker, amount, { "physical", "pierce" })
    end,
}
