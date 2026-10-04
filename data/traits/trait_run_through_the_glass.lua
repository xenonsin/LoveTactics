-- RUN THROUGH THE GLASS: the Sandman's escape, and the Hourglass that drops off him ("Sloth's Bestiary", slice G,
-- approved word for word; models/sandman.lua). When a foe ends its turn beside the bearer it runs out as sand and
-- reforms elsewhere, and the tile it left is a sand patch that sleeps whoever ends a turn on it.
--
-- ONE RULE, TWO REACHES, read off `traitParams.reach`:
--   none (the Sandman's organ)   he reforms on the tile his hourglass has marked, across the board. The mark is laid
--                                at the bell and moved after every run, and it is SHOWN -- that is the counter.
--   4 (the Hourglass, a Ninja's) the bearer reappears on the open tile within 4 farthest from the foe that came.
--
-- The patches are read here too, off where a turn ENDS (a patch does nothing to a body crossing it). A run is a
-- reflex: a stunned or sleeping bearer stays where it is.
local function S() return require("models.sandman") end

return {
    name = "Run Through the Glass",
    description = "When a foe ends its turn beside you, run out as sand and reform elsewhere. The tile you left sleeps whoever stops on it.",
    onCombatStart = function(ctx)
        if not ctx.param("reach", nil) then S().markFrom(ctx.combat, ctx.unit) end
    end,
    onAnyTurnEnd = function(ctx)
        S().turnEnded(ctx.combat, ctx.unit, ctx.actor, ctx.param("reach", nil))
    end,
}
