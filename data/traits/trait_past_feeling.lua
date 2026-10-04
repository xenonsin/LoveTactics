-- PAST FEELING: the first half of the Bog-Bound's line rule, carried on their organ (utility_bog_bound;
-- "Sloth's Bestiary", 2026-10-04, slice C). A blow of 8 damage or less does nothing; anything heavier lands in full.
--
-- The rule is asked from the damage path (models/sloth_bog.lua's pastFeeling, read off the `pastFeeling` flag).
-- This file only puts the badge on at the bell and keeps its number honest: a Cairn-Keeper walking up or falling
-- moves it between 8 and 16, so it is re-read whenever any turn opens or closes. `notAReaction`: a stunned mummy
-- feels no more than an awake one.
local function sync(ctx) require("models.sloth_bog").sync(ctx.combat) end

return {
    name = "Past Feeling",
    description = "A blow of 8 damage or less does nothing to you. A blow of 9 or more lands in full.",
    pastFeeling = true,
    notAReaction = true,
    onCombatStart = function(ctx)
        local u = ctx.unit
        local SlothBog = require("models.sloth_bog")
        SlothBog.live = true
        if u and u.alive then ctx.applyStatus(u, SlothBog.BADGE, { applier = u }) end
        SlothBog.sync(ctx.combat)
    end,
    onTurnStart = sync,
    onTurnEnd = sync,
    onAnyTurnStart = sync,
    onAnyTurnEnd = sync,
}
