-- PUFFCAPS: Act 0's spore pods, growing wild in the wood (2026-10-21).
--
-- The Champion's Roar is where the prologue shows these, and it is the only place it does. On the
-- floor itself they are a patch of their own, fielded as the unpinned copy (character_puffcap.lua).
--
-- WHAT IT ASKS is the one read the pod has: it has no strike, it rushes, and it bursts when it dies or
-- when it pulls its own pin over a two-tick channel. Kill it where its ring catches nobody, or step
-- clear while it winds up. A fight with nothing to block and everything to stand away from, which no
-- other stop on the floor is.
local Band = require("models.band")

return {
    name = "Puffcaps",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "forest" end,
    rung = 1, -- home floor of the circle (models/encounter.lua)
    -- THREE OR FOUR. Ten health each and no blow of their own, so the count is the whole threat: one
    -- pod is a step to the side, four arriving together is a board with no safe tile on it.
    composition = function(ctx)
        return Band.fill({}, ctx, "character_puffcap", { base = 3, min = 3, max = 4, per = 5 })
    end,
}
