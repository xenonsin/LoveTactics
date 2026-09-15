-- A Hard Season -- an augment (models/augment.lua): a danger staked on a bounty before it is taken.
--
-- The plainest danger there is, and the one every other augment is priced against: two levels
-- on everything, which under subtractive mitigation is damage taken rather than a wall
-- (models/growth.lua). It pays in coin because a level is not a thing, it is a tax on the
-- whole run, so what it should raise is the whole run's worth.
--
-- The stake is spent at the moment the posting is TAKEN, and it is gone whether the run is cleared or
-- lost. That is what makes it a bet rather than a fee.
return {
    name = "A Hard Season",
    description = "Everything out there is a little further along than you are.",

    -- +N on every body's level. Rides quest.floorLevel.
    levels = 2,

    -- What it pays: a multiplier on the posting's coin.
    gold = 0.5,

    -- WHAT IT COSTS, in the stock the Forge spends -- so making a run richer is priced against the
    -- upgrade you were saving for.
    cost = {
        material_iron_scrap = 3,
    },
}
