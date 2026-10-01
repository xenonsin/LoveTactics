-- THE LION'S SHARE: the Lion's rule (data/items/utility/utility_the_lions_share.lua). Approved 2026-09-30 on
-- Pride's bestiary review.
--
-- Two halves. The hunt is a planner preference on his blueprint (targetPref "held": a foe Rooted at 1, which is
-- what his lionesses leave him). The roar is here: when he makes a kill, every lioness of his side heals 20% of
-- her health, wherever she stands, and every foe within 2 of him is Rattled.
--
-- "He made the kill" is the fallen's lastAttacker, as the Redcap's Drying Cap reads it. Rattled is the injury's
-- own status (status_rattled), handed a fight's duration here rather than its standing one.
return {
    name = "The Lion's Share",
    description = "Goes for held prey first. Its kill roars: every lioness heals 20%, and foes within 2 are Rattled.",
    heal = 0.20,
    radius = 2,
    duration = 8,
    onAnyDeath = function(ctx)
        local u, fallen = ctx.unit, ctx.fallen
        if not (u and u.alive and fallen and fallen.lastAttacker == u and fallen.side ~= u.side) then return end
        local Combat = require("models.combat")
        local Trait = require("models.trait")
        ctx.log("action", string.format("%s roars over the kill.", (u.char and u.char.name) or "It"), u)
        for _, a in ipairs(ctx.combat.units) do
            if a ~= u and a.alive and a.side == u.side and Trait.has(a, "trait_the_king_eats_first") then
                ctx.heal(a, math.max(1, math.floor(Combat.unreservedMax(a.char, "health") * ctx.param("heal", 0.2) + 0.5)))
            end
        end
        for _, f in ipairs(ctx.unitsNear(u.x, u.y, ctx.param("radius", 2))) do
            if f.alive and f.side ~= u.side then
                ctx.applyStatus(f, "status_rattled", { applier = u, duration = ctx.param("duration", 8) })
            end
        end
    end,
}
