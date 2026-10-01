-- LIGHT-BEARER: Superbia's fame, carried by her Reflections and by the Halo of the Morning (reviewed over three
-- rounds, "Pride's Generals"). A foe whose turn opens with a line of sight to the bearer is Blinded until that
-- turn ends; a foe out of the bearer's sight is not.
--
-- So the counterplay is the board: come at her from behind cover, or not at all. Sight is the line a bow's
-- `requiresSight` asks (Combat.unitsSighted). Heard through Trait.onAnyTurnStart, and lifted on the same body's
-- onAnyTurnEnd -- only the Blind the light laid, so a Blind from somewhere else keeps its own clock.
local MorningStar = function() return require("models.morning_star") end

return {
    name = "Light-Bearer",
    description = "Foes that start their turn able to see you are Blinded until it ends.",
    notAReaction = true,
    onAnyTurnStart = function(ctx)
        MorningStar().dazzle(ctx.combat, ctx.unit, ctx.actor)
    end,
    onAnyTurnEnd = function(ctx)
        MorningStar().undazzle(ctx.combat, ctx.actor)
    end,
}
