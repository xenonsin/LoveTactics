-- Encounter blueprint. THE WEEPING STONE: a relic sold for blood rather than coin.
--
-- The third and last way a floor lets a company SPEND on the pile, and deliberately the only one whose
-- price is not gold. The Merchant sells at a fair price in the currency a run forages; the Altar wagers
-- coin against an unseen card. This one asks for something a purse cannot cover -- a permanent cut to
-- what the company can hold, for the rest of the descent -- and pays for it with a relic a rung above
-- what the floor would otherwise deal.
--
-- ITS OWN STOP RATHER THAN A THIRD VERB ON THE ALTAR. The Altar's two verbs already both spend things
-- you can count in your hand -- coin, and relics. A third that spends the company's bodies would make
-- one stop mean three unrelated things, and a floor guarantees its stops BY KIND (models/descent.lua's
-- guaranteeKinds), so a price this distinct needs a place of its own to be reliably met at all.
--
-- Uncommon, and it does not appear on the first floor: a company that has not yet been hurt has nothing
-- to weigh the price against, and a maximum-health toll taken before the first fight is a number rather
-- than a decision.
return {
    name = "The Weeping Stone",
    kind = "weeping_stone",
    weight = 2,
    minDay = 2,
}
