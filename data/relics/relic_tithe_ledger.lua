-- GREED · VICE · overworld · common. The Undercroft's whole argument in one object: it pays, and it
-- keeps a running note of what you owe for being paid.
--
-- The gold arrives per cleared stop, which on a descent is where gold arrives anyway (the payout was
-- rebased onto the fight rather than the quest -- models/spoils.lua). The cost lands on the party's
-- health so the two halves are in different currencies and cannot simply net out.
return {
    name = "The Tithe Ledger",
    blurb = "Coin off every fight, and a page of it taken out of the company.",
    tier = "common", alignment = "vice", affinity = "overworld", weight = 2,
    sin = "greed",
    cost = "Each cleared fight costs the party a little health.",
    encounterCleared = function(_, bucket, ctx)
        local bonus = math.max(10, math.floor(((ctx.spoils and ctx.spoils.gold) or 20) * 0.5))
        bucket.taken = (bucket.taken or 0) + bonus
        ctx.addGold(bonus)
        for _, c in ipairs(ctx.party) do ctx.drain(c, "health", 3) end
        ctx.say("The Tithe Ledger  +" .. bonus .. "g")
    end,
    banked = function(bucket) return bucket.taken end,
}
