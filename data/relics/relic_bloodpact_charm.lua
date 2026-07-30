-- VICE · both · rare. The whole party opens every fight Emboldened (status_heroism) -- and the pact
-- feeds on you, taking a drop of blood for every new step of road. Raw front-loaded power the run pays
-- for continuously: the further you push, the more it costs to carry.
return {
    name = "Bloodpact Charm",
    blurb = "The whole party opens every fight emboldened -- but you bleed for every step of new road.",
    tier = "rare", alignment = "vice", affinity = "both", weight = 1,
    cost = "Lose a little health for each newly explored tile.",
    battleStart = function(_, _, ctx)
        for _, c in ipairs(ctx.party) do ctx.grantBoon(c, "status_heroism") end
    end,
    step = function(_, bucket, ctx)
        local cell = ctx.cell
        if not cell or cell.bled then return end
        cell.bled = true
        local victim = ctx.frontRow()[1] or ctx.party[1]
        if victim then
            local lost = ctx.drain(victim, "health", 1)
            bucket.paid = (bucket.paid or 0) + lost
        end
    end,
    banked = function(bucket) return bucket.paid end,
}
