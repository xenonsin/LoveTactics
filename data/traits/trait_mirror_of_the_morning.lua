-- MIRROR OF THE MORNING: the Host, once, for a summoner (reviewed over three rounds, "Pride's Generals"). The
-- first time each fight the bearer is wounded below two-thirds health, two Reflections of the Morning -- felled
-- by any blow -- are called to fight beside it (models/morning_star.lua's mirror).
local MorningStar = function() return require("models.morning_star") end

return {
    name = "Mirror of the Morning",
    description = "Below two-thirds health, once a fight: two Reflections fight beside you.",
    notAReaction = true,
    onDamaged = function(ctx)
        MorningStar().mirror(ctx.combat, ctx.unit, ctx.trait)
    end,
}
