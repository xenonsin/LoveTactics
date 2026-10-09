-- DUCAL ASCENSION: the Archon Duke's first rule (data/characters/character_archon_duke.lua; "The Crown's Bestiary",
-- slice A, 2026-10-09). Any wisp within 3 of the Duke goes to the Duke instead of to its own body; the Duke takes it
-- in and that Archon stays down. At the third wisp taken, the Duke Ascends: a new body, healed to full, with new
-- spells (character_archon_duke_ascended).
--
-- BUILT ON SPIRIT BODY'S TWO SEAMS (models/spirit.lua): a claimed wisp's `wispGoal` is the Duke, and arriving beside
-- it fires `onWispTaken` here. The claim is re-asked whenever a wisp may have moved -- a death throws one, and every
-- turn's start and end can carry one into reach -- so the court's wisps are the Duke's the moment they come near.
local function Court() return require("models.archon_court") end

return {
    name = "Ducal Ascension",
    description = "Takes in any wisp within 3. At the third, it Ascends: a new body, healed to full.",
    takesWisps = true,
    reach = 3,
    need = 3,
    maxStacks = 3,
    onCombatStart = function(ctx) Court().claimWisps(ctx.combat, ctx.unit) end,
    onAnyDeath = function(ctx) Court().claimWisps(ctx.combat, ctx.unit) end,
    onAnyTurnStart = function(ctx) Court().claimWisps(ctx.combat, ctx.unit) end,
    onAnyTurnEnd = function(ctx) Court().claimWisps(ctx.combat, ctx.unit) end,
    onTurnStart = function(ctx) Court().claimWisps(ctx.combat, ctx.unit) end,
    onTurnEnd = function(ctx) Court().claimWisps(ctx.combat, ctx.unit) end,
    onWispTaken = function(ctx) Court().takeWisp(ctx.combat, ctx.unit, ctx.trait) end,
}
