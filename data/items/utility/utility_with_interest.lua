-- Cass's bound relic (Mammonite). She charges for the work, then charges again for the danger.
--
-- NO REFUND, and that is the whole design. An earlier draft handed the purse back on the blow, which
-- made spending free -- and a greed relic that costs nothing is the one thing it must never be. Worse,
-- it meant the interesting question (spend it now on Blood Money, or hold it for this) had no wrong
-- answer. The coin is gone. She bought the damage and it stays bought.
--
-- IT BANKS `goldSpent`, filled at Combat.spendPurse where the amount is already known -- so it counts
-- what actually LEFT the purse rather than what was asked for. A broke party's last coppers buy a
-- smaller blow, which is the honest number.
--
-- The shelf splits cleanly around it: the spenders (Blood Money, The Gilded Wound, Grease Palms, The
-- Open Account) are the gate AND the price, and the earners (The Ledger's Due, Skimmer's Cut, A Price
-- on the Head) are what let her keep affording to fill it. A Mammonite who never spends never collects.
return {
    name = "With Interest",
    description = "One blow for every coin you have spent this fight. The gold does not come back.",
    flavor = "The work was the cheap part. She itemises the rest afterwards.",
    sprite = "assets/items/sig_with_interest.png",
    type = "utility",
    tags = { "signature", "impact" },
    class = "mammonite",
    activeAbility = {
        target = "enemy",
        range = 4,
        requiresSight = true,
        speed = 5,
        cost = { stat = "stamina", amount = 8 },
        description = "Strikes for a share of every coin you have spent this fight.",
        unlock = { event = "goldSpent", count = 200, text = "Spend 200 gold" },
        -- The outlay made visible, so she can watch the bill grow rather than doing the arithmetic in
        -- her head. Same tally the effect reads, so the badge and the blow agree.
        counter = function(unit)
            return unit and require("models.combat").tallyCount(unit, "goldSpent") or 0
        end,
        counterLabel = "Spent",
        effect = function(fx)
            -- The whole outlay, read live so a surplus spent past the gate is collected too. Divided
            -- down because gold and damage are not the same unit -- two hundred spent is a heavy blow,
            -- not a deleted board.
            local Combat = require("models.combat")
            local outlay = Combat.tallyCount(fx.user, "goldSpent")
            fx.damage(fx.target, { amount = math.floor(outlay / 8) })
        end,
    },
    -- one blow per coin, and the coins were spent on blows
    bonus = { damage = 2 },
}
