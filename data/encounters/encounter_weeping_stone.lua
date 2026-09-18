-- PARKED 2026-09-17. The Stone sells a run relic for a permanent cut to the company's maximum health,
-- and models/relic.lua is parked (see the dated note at its head), so the price buys nothing. `parked =
-- true` is read by models/encounter.lua's `eligible`; the blueprint and its handler in states/game.lua
-- remain on disk. It was also GUARANTEED from floor two -- models/descent.lua's `guaranteeKinds` -- and
-- that entry is struck there, so lifting this one takes an edit in both places.
--
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
    parked = true,
    weight = 2,
    minDay = 2,
}
