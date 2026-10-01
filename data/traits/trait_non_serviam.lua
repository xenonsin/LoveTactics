-- NON SERVIAM: Superbia's rejection, and the rule her relic carries (reviewed over three rounds, "Pride's
-- Generals"). A debuff a foe lays on the bearer REBOUNDS onto whoever laid it, at the length it was laid.
--
-- Not Incorruptible, which refuses, and not a reflect, which returns damage: the debuff is sent back whole.
-- Answered in Status.apply (models/morning_star.lua), ahead of every wall, so a rebound never reaches them.
--
-- Two numbers, read through the granting item (Trait.param):
--   oncePerTurn  the bearer sends back one debuff between the ends of its own turns (the Morning Star relic)
--   refusesAll   a debuff with nobody to send it to is refused as well (Superbia herself: it never touches her)
return {
    name = "Non Serviam",
    description = "Foes' debuffs rebound onto whoever laid them.",
    nonServiam = true,
    oncePerTurn = false,
    refusesAll = true,
    notAReaction = true,
    onTurnEnd = function(ctx)
        ctx.unit.reboundSpent = nil
    end,
}
