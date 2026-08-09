-- GLUTTONY · VIRTUE · overworld · common. The circle that swallows what walks into it, turned the
-- other way round: every cleared stop feeds the company a little instead of costing it.
--
-- The clean answer to the wound meter (models/wound.lua) without undoing it: this gives HEALTH back
-- between fights, which is the resource a descent actually spends, and it cannot lift anybody past a
-- wound's ceiling because it pours through the same restore the hub does.
return {
    name = "The Deep Larder",
    blurb = "Every fight you clear feeds the company: a little health back, all the way down.",
    tier = "common", alignment = "virtue", affinity = "overworld", weight = 2,
    sin = "gluttony",
    encounterCleared = function(_, bucket, ctx)
        local given = 0
        for _, c in ipairs(ctx.party) do given = given + (ctx.restore(c, "health", 6) or 0) end
        if given > 0 then
            bucket.fed = (bucket.fed or 0) + given
            ctx.say("The Deep Larder  +" .. given .. " health")
        end
    end,
    banked = function(bucket) return bucket.fed end,
}
