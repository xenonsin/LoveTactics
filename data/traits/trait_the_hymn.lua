-- THE HYMN: the Herald's rule, and the rule its trumpet carries out of the spire (reviewed 2026-09-30, "Pride's
-- Bestiary"). At the end of the bearer's turn, every ally within 2 of it is Blessed (status_blessing, the
-- priest's own offensive benediction) -- the bearer itself excluded: a herald announces, it is not announced.
--
-- `kin` narrows WHO hears it. The Herald's organ (utility_the_hymn) names "angel", so in a fight the choir shares
-- with the gilded only the angels sing louder; the Herald's Trumpet names nobody, and blesses every ally. Laid
-- with the bearer as the applier, which is what lets it land on an Incorruptible angel: its own side laid it.
local RADIUS = 2

return {
    name = "The Hymn",
    description = "At the end of your turn, allies within 2 are Blessed.",
    notAReaction = true,
    radius = RADIUS,
    onTurnEnd = function(ctx)
        local u = ctx.unit
        if not (u and u.alive and ctx.combat) then return end
        local Combat = require("models.combat")
        local kin = ctx.param("kin", nil)
        local reach = ctx.param("radius", RADIUS)
        for _, ally in ipairs(ctx.combat.units or {}) do
            if ally ~= u and ally.alive and ally.side == u.side and not Combat.isOffTile(ally)
                and Combat.unitGap(u, ally) <= reach
                and (not kin or (ally.char and ally.char.race == kin)) then
                ctx.applyStatus(ally, "status_blessing", { applier = u })
            end
        end
    end,
}
