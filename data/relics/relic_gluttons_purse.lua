-- COMMON. The one gold relic left standing, and the reason it survived a cull that took four others is
-- that its COST LANDS IN THE FIGHT. Pilgrim's Coin, the Tithe Ledger, Cursed Lucre and Poacher's Map
-- were all bookkeeping -- nothing about them changed a board -- and a relic that cannot be felt where
-- the game is played is a relic the player never notices working.
--
-- This one you feel: the purse sits heavy, and the company opens each fight with its wind knocked out.
return {
    name = "Glutton's Purse",
    blurb = "Double gold from every fight, and at least +%d.",
    tier = "common", mark = "Pu",
    cost = "-4 stamina for the whole company at the opening bell.",
    scale = { 6, 4 },
    encounterCleared = function(_, bucket, ctx)
        local base = (ctx.spoils and ctx.spoils.gold) or 10
        local bonus = math.max(ctx.mag(6, 4), math.floor(base))
        bucket.taken = (bucket.taken or 0) + bonus
        ctx.addGold(bonus)
        ctx.say("Glutton's Purse  +" .. bonus .. "g")
    end,
    battleStart = function(_, _, ctx)
        for _, c in ipairs(ctx.party) do ctx.drain(c, "stamina", 4) end
    end,
    banked = function(bucket) return bucket.taken end,
}
