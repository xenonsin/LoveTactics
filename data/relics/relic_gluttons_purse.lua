-- VICE · overworld · common. Twice the coin off every win -- but greed sits heavy, and the party opens
-- each fight with its wind knocked out (stamina spent before the bell). The gentle end of the Vice shelf:
-- a real, felt cost, but a survivable one.
return {
    name = "Glutton's Purse",
    blurb = "Double gold from every fight -- but the party opens each fight winded.",
    tier = "common", alignment = "vice", affinity = "overworld", weight = 2,
    cost = "The party starts each fight with less stamina.",
    encounterCleared = function(_, bucket, ctx)
        local base = (ctx.spoils and ctx.spoils.gold) or 10
        local bonus = math.max(6, math.floor(base))
        bucket.taken = (bucket.taken or 0) + bonus
        ctx.addGold(bonus)
        ctx.say("Glutton's Purse  +" .. bonus .. "g")
    end,
    battleStart = function(_, _, ctx)
        for _, c in ipairs(ctx.party) do ctx.drain(c, "stamina", 4) end
    end,
    banked = function(bucket) return bucket.taken end,
}
