-- Grease Palms: time is money, bought the other way round -- money into time. Spend from the purse
-- (Combat.spendPurse, via fx.spendPurse) to Haste yourself or an ally, and the more coin you push across
-- the table the LONGER the haste runs. The second exemplar of the rogue's money kit, showing the other
-- face of it: the first (Blood Money) buys damage, this one buys tempo -- initiative, the one currency
-- nobody otherwise gets back.
--
-- WHY IT IS NOT JUST OVERCHARGE. The Artificer's Overcharge (data/items/ability/ability_overcharge.lua)
-- also grants Haste, for a flat stamina price and a flat default length. This one costs coin instead and
-- hands you the DURATION DIAL: a token haste when the purse is empty, a long one when it is fat. You are
-- not buying the effect, you are buying how much of it -- which is the greed shelf's whole relationship
-- with everything.
--
-- Deterministic, no gamble: duration = a small floor plus one tick for every few coins poured, clamped by
-- a cap so a fortune cannot buy an entire battle of haste off one cast. A broke party still gets the floor
-- -- a brief quickening -- so the cast is never dead, it is only ever cheap.
return {
    name = "Grease Palms",
    description = "Hastes an ally -- and the more gold you spend from your purse, the longer the haste lasts.",
    flavor = "A door is only locked to those who have not paid the doorman.",
    sprite = "assets/items/ability_grease_palms.png",
    type = "ability",
    tags = { "guile" }, -- the rogue's word; the purse is the header's business, as on Blood Money
    class = "rogue",
    discipline = "mammonite", -- a spender: the gate opens the shelf, this half completes it at quest 9
    price = 440,
    -- Gated to the END of the greed line: on sale only once all ten Undercroft quests are cleared -- i.e.
    -- Aurea is beaten (slot 10). The whole money kit is her art, earned by taking it off her.
    unlockQuests = 6,
    activeAbility = {
        target = "ally",
        range = 2,
        speed = 3,
        support = true,
        cost = { stat = "stamina", amount = 3 },
        description = "Spends up to your affordable pour of gold to Haste an ally; each 3 gold buys 1 extra tick.",
        effect = function(fx)
            local t = fx.target
            if not t then return end
            -- Floor + a tick per three coins, capped. The pour widens a little with the forge (a honed
            -- palm greases further), but the real lever is the wallet: 10 ticks with an empty purse,
            -- up to ~40 with a full one. Combat.spendPurse clamps to what is actually on hand.
            local cap = 75 + fx.level * 15
            local spent = fx.spendPurse(cap)
            local duration = 10 + math.floor(spent / 3)
            fx.applyStatus(t, "status_hasted", { duration = duration })
        end,
    },
}
