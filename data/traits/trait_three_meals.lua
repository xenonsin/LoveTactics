-- THREE MEALS: the Sated's rule, reviewed over two rounds on 2026-09-23 ("The Sated and the Flight").
--
-- It opens holding three meals (status_full). A meal is weight: +3 Damage and +3 Defense, -1 Movement
-- and -1 Speed apiece, so at the bell it is an armoured wall that barely moves, and with the belly empty
-- it is a large, quick, soft animal. What round one pitched -- a meal torn out of it at each quarter of
-- its health, a beast spilling out onto the board -- was denied ("I don't know if I like it spitting up
-- beasts"), and so was any drain on health at all ("just like lose more"). What survived:
--
--   SPENT      its big moves are paid in meals (ability_retch, ability_settle -- fx.spendStacks). The
--              Sated chooses when to get lighter, and the badge counts its big moves down.
--   KNOCKED    a critical hit knocks a meal loose. The one lever the company holds on the count.
--   EATEN      anything, of either side, that dies beside it is eaten and puts a meal back (capped at
--              three -- "overfull at five" was denied). A company member eaten this way is out for this
--              fight only, the same rule as Gula's (Combat.devour).
--
-- So the counterplay is to keep bodies from falling at its feet: kill its hawks away from it, do not go
-- down beside it, and let it spend itself.
--
-- A HAWK MANTLING SOMETHING THAT DIES HERE IS EATEN WITH IT (review, round two: "a mantled body is on
-- the menu"). The prey carries `mantledBy` (data/traits/trait_mantling.lua); the bird is devoured on the
-- spot and is a second meal.
--
-- `notAReaction`: a stunned Sated still loses a meal to a critical. It is not answering the blow; the
-- blow is simply knocking something out of it.
local Status = require("models.status")

local function feed(ctx, n, what)
    Status.apply(ctx.combat, ctx.unit, "status_full", { magnitude = n or 1 })
    ctx.log("action", string.format("%s eats %s.", (ctx.unit.char and ctx.unit.char.name) or "It",
        what or "what fell beside it"), ctx.unit)
end

return {
    name = "Three Meals",
    description = "Opens holding three meals. Eats whatever dies beside it; a critical hit knocks a meal loose.",
    notAReaction = true,
    meals = 3,
    onCombatStart = function(ctx)
        Status.apply(ctx.combat, ctx.unit, "status_full", { magnitude = ctx.param("meals", 3) })
    end,
    onDamaged = function(ctx)
        if not ctx.critical then return end
        if Status.spendStacks(ctx.combat, ctx.unit, "status_full", 1) then
            ctx.log("action", string.format("The blow knocks a meal loose from %s.",
                (ctx.unit.char and ctx.unit.char.name) or "it"), ctx.unit)
        end
    end,
    onAnyDeath = function(ctx)
        local fallen, u = ctx.fallen, ctx.unit
        if not (fallen and u and u.alive) or fallen == u or fallen.eatenBy then return end
        if ctx.gap(fallen) > 1 then return end
        local Combat = require("models.combat")
        fallen.eatenBy = u
        Combat.devour(ctx.combat, u, fallen)
        feed(ctx, 1, (fallen.char and fallen.char.name) or "the body")
        local hawk = fallen.mantledBy
        if hawk and hawk.alive and hawk ~= u then
            hawk.eatenBy = u
            if Combat.devour(ctx.combat, u, hawk) then
                feed(ctx, 1, (hawk.char and hawk.char.name) or "the hawk")
            end
        end
    end,
}
