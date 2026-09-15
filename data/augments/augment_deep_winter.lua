-- Deep Winter -- an augment (models/augment.lua): a danger staked on a bounty before it is taken.
--
-- All three axes at once, at a price that only a company with a real bench can pay. It exists so
-- the ceiling of this system is one item rather than an arithmetic exercise: the most
-- dangerous run the game can produce is three of these, and that is a sentence a reader can
-- check rather than derive.
--
-- The stake is spent at the moment the posting is TAKEN, and it is gone whether the run is cleared or
-- lost. That is what makes it a bet rather than a fee.
return {
    name = "Deep Winter",
    description = "Further along, further out, and worse at the end of it.",

    -- +N on every body's level. Rides quest.floorLevel.
    levels = 2,

    -- +N stops on the way. Rides map.encounters.
    fights = 2,

    -- +N bodies standing with the boss. Rides the objective's own guard count.
    guard = 2,

    -- What it pays: a multiplier on the posting's coin.
    gold = 0.8,

    -- What it pays: extra postings put back in hand.
    drops = 1,

    -- WHAT IT COSTS, in the stock the Forge spends -- so making a run richer is priced against the
    -- upgrade you were saving for.
    cost = {
        material_mythril = 1,
        material_steel_ingot = 2,
    },
}
