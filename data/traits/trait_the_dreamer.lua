-- THE DREAMER: Desidia's Long Sleep and her phase two, carried on her organ (data/items/utility/utility_the_dreamer.lua;
-- "Sloth's Bestiary", slice G, both rows approved word for word). Every step lives in models/desidia.lua, which
-- argues it in full; this file only says when each step runs.
--
--   onCombatStart  she is seated at the far edge, and opens Dormant
--   onAnyCast      an attack or ability used anywhere adds a Stir while she sleeps; at 10 she wakes
--   onDamaged      a blow wakes her early -- and, awake, is the blow that keeps her up this round
--   onTurnEnd      asleep, she banks a turn and marks its row; awake, a round without a blow puts her back under
--   onDeath        her rows go with her
--
-- `notAReaction`: Dormant shuts her reflexes off, and none of this is a reflex -- a sleeping god still wakes when you
-- hit her. `unmoved`: the face is the top of a body under the glacier, and nothing shoves it.
local function D() return require("models.desidia") end

return {
    name = "The Dreamer",
    description = "Sleeps, banking a turn a round. The board's noise or a blow wakes her, and every banked turn sweeps a row.",
    notAReaction = true,
    unmoved = true,
    onCombatStart = function(ctx) D().open(ctx.combat, ctx.unit) end,
    onAnyCast = function(ctx) D().stir(ctx.combat, ctx.unit) end,
    onDamaged = function(ctx) D().struck(ctx.combat, ctx.unit, ctx.amount) end,
    onTurnEnd = function(ctx) D().turnEnd(ctx.combat, ctx.unit) end,
    onDeath = function(ctx) D().onDeath(ctx.combat, ctx.unit) end,
}
