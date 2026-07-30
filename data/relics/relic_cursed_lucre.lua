-- VICE · overworld · common. The coin bites the hand: a fat purse off every win, but the winnings are
-- paid in a pound of the most-wounded's flesh. Turns each fight into a greedy bargain -- take the gold,
-- and the ally already hurting pays for it.
return {
    name = "Cursed Lucre",
    blurb = "A rich purse from every fight -- but the most-wounded ally pays for it in blood.",
    tier = "common", alignment = "vice", affinity = "overworld", weight = 2,
    cost = "The most-wounded ally loses health after each fight.",
    encounterCleared = function(_, bucket, ctx)
        bucket.taken = (bucket.taken or 0) + 12
        ctx.addGold(12)
        local victim = ctx.mostWounded() or ctx.party[1]
        if victim then ctx.drain(victim, "health", 3) end
        ctx.say("Cursed Lucre  +12g, and it bites")
    end,
    banked = function(bucket) return bucket.taken end,
}
