-- EVERY COIN COUNTED: Avaritia knows exactly what was taken (reviewed 2026-09-25, "Avaritia, the Unspent";
-- round 2 made it remember across trips).
--
-- One stack for every coin heap the company takes from her -- in her fight (data/hazards/hazard_coin_heap.lua
-- asks for the `countsEveryCoin` flag on every body that sees a heap go), and in the Burglary on any trip
-- before it (models/hoard.lua: she opens her fight already holding one stack per heap ever carried out of
-- her treasury). +2 Damage a stack, no cap. The dwarves' Dragon-Sickness curve pointed the other way: a
-- heap taken from her is armour off her Gilded Belly, and a grudge added to her claws.
return {
    name = "Every Coin Counted",
    abbr = "Coin",
    description = "Each heap taken from her hoard: increase damage.",
    color = { 0.690, 0.470, 0.160 }, -- badge tint (old gold, darker than Dragon-Sickness)
    duration = math.huge,
    hideDuration = true, -- the count is the story
    magnitude = 1,
    stacks = 99, -- a count, not a cap
    statBonus = { damage = 2 },
    statBonusScales = true,
}
