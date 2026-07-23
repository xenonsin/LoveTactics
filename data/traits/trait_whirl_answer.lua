-- Whirl Answer: struck, the wearer turns all the way round with the blade out -- and everything
-- standing next to them takes it, not only whoever swung.
--
-- The one retaliation in this file that does not care who the attacker was. Every other counter here
-- (parry, riposte, thorns, shield bash) answers the hand that reached in, which makes all of them
-- worth exactly one enemy. This answers the SITUATION, so its value is the number of bodies around
-- the wearer -- which turns being surrounded from the thing that kills a fighter into the thing that
-- pays them. That is the same inversion `frenzy` performs for a swing (see castAmount in
-- models/combat.lua), arriving from the defensive side.
--
-- Because it is an area answer it declines to be an area's answer: `counter.area` is not set, so a
-- blast that catches the wearer among others provokes nothing, exactly as every other reflex in this
-- game declines to answer an AoE. A fighter ringed by five foes who all swing gets five whirls; a
-- fighter caught by one fireball gets none.
--
-- Priced through the ordinary answer economy (ctx.pay -> Trait.answerCost), so the second whirl in a
-- round costs double the first and the fourth runs the wearer dry. That escalation is what keeps
-- "surrounded by six" from being strictly better than "surrounded by two" without a cap anyone had to
-- write, and it is visible to the player as a stamina bar draining rather than as a hidden cooldown.
--
-- It hits ALLIES standing adjacent too. A whirl is a whirl.
return {
    name = "Whirl Answer",
    description = "When struck in melee, cuts everything adjacent rather than only the attacker.",
    magnitude = 8, -- flat damage to each body around the wearer
    counter = { reach = "melee", requiresTag = "physical" },
    cost = { stat = "stamina", amount = 4 },
    onDamaged = function(ctx)
        if not ctx.mayCounter() then return end
        if not ctx.pay() then return end
        local caught = 0
        for _, u in ipairs(ctx.unitsNear(ctx.unit.x, ctx.unit.y, 1)) do
            if u ~= ctx.unit and u.alive then
                ctx.damage(u, ctx.def.magnitude or 8, { "physical", "slash" })
                caught = caught + 1
            end
        end
        if caught > 0 then
            ctx.log("status", string.format("%s answers with a full turn of the blade (%d caught).",
                ctx.unit.char and ctx.unit.char.name or "Unit", caught), ctx.unit)
        end
    end,
}
