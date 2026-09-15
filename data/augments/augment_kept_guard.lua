-- A Kept Guard -- an augment (models/augment.lua): a danger staked on a bounty before it is taken.
--
-- Bodies at the END, and nowhere else. The one augment that leaves the road exactly as it was and
-- spends everything on the fight you came for, which is the opposite trade to The Long Road --
-- arrive intact and it is the hardest thing on this list, arrive worn and it is the worst.
--
-- The stake is spent at the moment the posting is TAKEN, and it is gone whether the run is cleared or
-- lost. That is what makes it a bet rather than a fee.
return {
    name = "A Kept Guard",
    description = "It did not come alone.",

    -- +N bodies standing with the boss. Rides the objective's own guard count.
    guard = 3,

    -- What it pays: a multiplier on the posting's coin.
    gold = 0.6,

    -- WHAT IT COSTS, in the stock the Forge spends -- so making a run richer is priced against the
    -- upgrade you were saving for.
    cost = {
        material_iron_scrap = 2,
        material_steel_ingot = 1,
    },
}
