-- THE HOST AND THE FALL: Superbia's two stages, which both happen, in order (reviewed over three rounds,
-- "Pride's Generals"). The rules are models/morning_star.lua's; this file is only where they are heard.
--
--   THE HOST DESCENDS  at two-thirds health two Reflections of the Morning are called beside her, and two more at
--                      the end of each of her turns, until...
--   THE FALL           ...one-third: the Reflections shatter, she can no longer fly, and the ground around her
--                      breaks into Black Ice, a ring further at the end of each of her turns. +2 Damage per ring;
--                      a body that ends two turns running on the ice is Frozen.
--
-- Both stages fire on the blow that crosses them, and a blow that kills crosses none (trait_boss_phases'
-- threshold rule). NOT A REFLEX: stunning her does not keep the Host from descending.
local MorningStar = function() return require("models.morning_star") end

return {
    name = "The Host and the Fall",
    description = "At 2/3 health Reflections join her each turn. At 1/3 they shatter, she falls, and ice spreads.",
    notAReaction = true,
    onDamaged = function(ctx)
        MorningStar().onWound(ctx.combat, ctx.unit, ctx.trait)
    end,
    onTurnEnd = function(ctx)
        MorningStar().onOwnTurnEnd(ctx.combat, ctx.unit, ctx.trait)
    end,
    onAnyTurnEnd = function(ctx)
        MorningStar().iceTurn(ctx.combat, ctx.unit, ctx.trait, ctx.actor)
    end,
}
