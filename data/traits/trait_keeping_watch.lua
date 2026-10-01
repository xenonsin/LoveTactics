-- KEEPING WATCH: the half of the Virtue's Aegis that is not a cast (reviewed 2026-09-30, "Pride's Bestiary").
--
-- "The ally that took the most damage LAST ROUND" needs a round to measure, and this game has no rounds -- it has
-- turns on an initiative clock. So the round is the bearer's own: at the end of each of its turns this banks how
-- much every body on the field has taken so far (the `damageTaken` tally, Combat.tally), and the cast reads the
-- difference since. What the Aegis wards is whoever bled the most between the bearer's last turn and this one.
return {
    name = "Keeping Watch",
    description = "Remembers who has been hurt since the end of your last turn.",
    notAReaction = true,
    onTurnEnd = function(ctx)
        local u = ctx.unit
        if not (u and ctx.combat) then return end
        local Combat = require("models.combat")
        local seen = {}
        for _, other in ipairs(ctx.combat.units or {}) do
            seen[other] = Combat.tallyCount(other, "damageTaken")
        end
        u.watchSeen = seen
    end,
}
