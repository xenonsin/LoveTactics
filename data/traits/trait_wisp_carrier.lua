-- WISP-CARRIER: the Lesser Archon's rule (data/characters/character_lesser_archon.lua; the creature identity pass,
-- 2026-11-19). A wisp of its court within 3 that is nearer to it than to its own body comes to the Lesser Archon
-- instead; arriving, the body it left stands up at once, wherever it lies.
--
-- BUILT ON SPIRIT BODY'S TWO SEAMS (models/spirit.lua), exactly as the Duke's Ascension is: the claim sets the wisp's
-- `wispGoal`, and arriving beside the carrier fires `onWispTaken` here. The work is ArchonCourt.relayWisps /
-- relayArrive. It yields to a Duke: a wisp within the Duke's own reach is the Duke's.
local function Court() return require("models.archon_court") end

return {
    name = "Wisp-Carrier",
    description = "A fallen Archon's wisp within 3 comes to it, and its body stands at once.",
    carriesWisps = true,
    grade = 0.0, -- a body's own organ, never shelved (models/grade.lua weighs it here, beside the rule)
    reach = 3,
    onCombatStart = function(ctx) Court().relayWisps(ctx.combat, ctx.unit) end,
    onAnyDeath = function(ctx) Court().relayWisps(ctx.combat, ctx.unit) end,
    onAnyTurnStart = function(ctx) Court().relayWisps(ctx.combat, ctx.unit) end,
    onAnyTurnEnd = function(ctx) Court().relayWisps(ctx.combat, ctx.unit) end,
    onTurnStart = function(ctx) Court().relayWisps(ctx.combat, ctx.unit) end,
    onTurnEnd = function(ctx) Court().relayWisps(ctx.combat, ctx.unit) end,
    onWispTaken = function(ctx) Court().relayArrive(ctx.combat, ctx.unit, ctx.body) end,
}
