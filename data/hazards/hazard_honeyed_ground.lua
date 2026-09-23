-- Honeyed Ground: the Alraune's sweetness, poured out on the floor around whoever she aims at.
--
-- IT MENDS WHOEVER STANDS ON IT, and it has no side -- the New Growth's rule (hazard_bloom), for the
-- New Growth's reason: she is not helping anybody. The ground heals on arrival and puts a body to sleep
-- if its own turn ends there (data/status/status_honeyed.lua, which carries both beats), and a company
-- that steps in, drinks and steps off has been healed for free. The Mandrake's root is what takes the
-- stepping-off away, and the Gallows Seed is what decides who the healing was for.
--
-- OWNED BY THE ALRAUNE WHO POURED IT, so it goes when she does (models/hazard.lua drops a dead owner's
-- ground on the next tick). Cut the one doing it: the honey dries with her.
--
-- `neutral` to the planner, which is the honest reading of an unsided heal. The mushroom folk and her own
-- line are no more drawn onto it than a company is, and a body of hers that wanders in sleeps as readily.
return {
    name = "Honeyed Ground",
    description = "Heals whoever arrives on it; a turn ended on it ends in sleep.",
    tags = { "nature" },
    duration = 30,           -- about five turns: long enough to be a place, short enough to be a cast
    disposition = "neutral",
    onEnter = function(ctx)
        ctx.applyStatus(ctx.unit, "status_honeyed", { magnitude = ctx.amount })
    end,
}
