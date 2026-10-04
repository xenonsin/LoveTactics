-- SAND IN THE EYES: the Sandman's sowing (data/items/utility/utility_sand_in_the_eyes.lua; models/sandman.lua argues
-- it in full). "Sloth's Bestiary", slice G, approved word for word: each turn he sows sand on a telegraphed pattern
-- of tiles -- a cross, then a ring, then a row -- and anything standing on it at the start of his next turn falls
-- Asleep, on either side.
--
--   onTurnStart  last turn's sand comes due: everything on it but him falls Asleep, and it is lifted
--   onTurnEnd    the next shape in the cycle is sown where it catches the most of his foes
--   onDeath      his unspent sand and his mark go with him
--
-- `notAReaction`: none of it answers a blow, so a stunned Sandman's sand still comes due.
local function S() return require("models.sandman") end

return {
    name = "Sand in the Eyes",
    description = "Each turn, sows sand in a cross, a ring, then a row. Whatever stands on it at his next turn falls Asleep.",
    notAReaction = true,
    onTurnStart = function(ctx) S().reap(ctx.combat, ctx.unit) end,
    onTurnEnd = function(ctx) S().sowNext(ctx.combat, ctx.unit) end,
    onDeath = function(ctx) S().onDeath(ctx.combat, ctx.unit) end,
}
