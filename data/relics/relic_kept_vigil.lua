-- COMMON. The Cathedral's circle, read as the thing it is actually about in this story: someone sitting
-- up with you. The company is blessed going into every fight and steadied coming out of every one it
-- wins.
--
-- Two small halves rather than one large one, because that is what a vigil is -- present at the
-- beginning and still there at the end, and unremarkable at any single moment in between.
return {
    name = "The Kept Vigil",
    blurb = "Blessed going in, +%d mana coming out, every fight of the run.",
    tier = "common", mark = "Vi",
    sin = "lust",
    scale = { 4, 2 },
    battleStart = function(_, _, ctx)
        for _, c in ipairs(ctx.frontRow()) do ctx.grantBoon(c, "status_blessing") end
    end,
    encounterCleared = function(_, bucket, ctx)
        local given = 0
        for _, c in ipairs(ctx.party) do given = given + (ctx.restore(c, "mana", ctx.mag(4, 2)) or 0) end
        if given > 0 then
            bucket.kept = (bucket.kept or 0) + given
            ctx.say("The Kept Vigil  +" .. given .. " mana")
        end
    end,
    banked = function(bucket) return bucket.kept end,
}
