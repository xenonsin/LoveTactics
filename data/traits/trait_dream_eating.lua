-- DREAM-EATING: Baku's rule (data/items/utility/utility_dream_eating.lua; "Sloth's Bestiary", 2026-10-04). At the
-- start of its turn it feeds on every Asleep or Dormant body within 3, on either side: a tenth of its health
-- healed and +2 Damage for each (status_dream_fed, read fresh each turn; models/sloth_dreamers.lua).
--
-- The answer is the review's: wake your own sleepers -- hit them -- to starve it, and kill the moths that put them
-- under first. `notAReaction`: eating is what it is, and a Baku the moths put to sleep still eats when it wakes.
return {
    name = "Dream-Eating",
    description = "At the start of its turn, heals a tenth and gains damage for every sleeper within 3, either side.",
    notAReaction = true,
    onTurnStart = function(ctx)
        if ctx.unit and ctx.unit.alive then require("models.sloth_dreamers").feed(ctx.combat, ctx.unit) end
    end,
}
