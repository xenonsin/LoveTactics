-- STONE GAZE: Medusa's first rule, on her organ (data/items/utility/utility_stone_gaze.lua). A body of the company
-- that ends its turn in her sight within 4 gains Stone; at 3 it is Petrified. A body carrying a mirror turns it
-- back on her. models/gorgon.lua argues the reading; this file says when.
--
-- On the turn's END (onAnyTurnEnd), so it is where a body chose to stop that is judged, never a tile it crossed.
-- `notAReaction`: a stunned Gorgon still looks.
return {
    name = "Stone Gaze",
    description = "A foe that ends its turn in its sight within 4 gains Stone. At 3 Stone, Petrified for 2 turns.",
    notAReaction = true,
    onAnyTurnEnd = function(ctx)
        require("models.gorgon").gaze(ctx.combat, ctx.unit, ctx.actor)
    end,
}
