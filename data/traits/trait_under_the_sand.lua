-- UNDER THE SAND: Leviathan's rule, carried on its organ (data/items/utility/utility_under_the_sand.lua). Every
-- step of it lives in models/leviathan.lua, which argues the cycle in full; this file only says when each
-- step runs.
--
--   onCombatStart  it opens the fight under the sand
--   onTurnStart    the marks laid last turn come up -- the head rises, the tail erupts -- or a body that was up
--                  for its round dives again
--   onTurnEnd      under, it marks the 3x3 under the Fairest; below half, its tail marks the next-Fairest
--   onDeath        its marks go with it
--
-- `groundproof`: the sand it drowns the board in does not hold it (Hazard.shrugs -- every hostile zone, which
-- on the waste is its own quicksand and its own ripples). `underTheSand` is the flag AI.preempt and
-- Leviathan.isLeviathan read. `notAReaction`: none of this answers a blow, so a stun does not stop the sea.
local function L() return require("models.leviathan") end

return {
    name = "Under the Sand",
    description = "Under the sand between surfacings. Rises under the Fairest, shoving everyone out; the ground becomes quicksand.",
    underTheSand = true,
    groundproof = true,
    notAReaction = true,
    onCombatStart = function(ctx) L().dive(ctx.combat, ctx.unit) end,
    onTurnStart = function(ctx) L().turnStart(ctx.combat, ctx.unit) end,
    onTurnEnd = function(ctx) L().turnEnd(ctx.combat, ctx.unit) end,
    onDeath = function(ctx) L().onDeath(ctx.combat, ctx.unit) end,
}
