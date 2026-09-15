-- Bad Company -- an augment (models/augment.lua): a danger staked on a bounty before it is taken.
--
-- Raises the share of stops allowed to be an elite. It is the augment that changes the SHAPE of
-- a road rather than its length or its level: the same number of fights, more of them worth
-- stopping for. Priced in steel because it is a mid-ladder decision -- a company with scrap
-- and nothing else is not ready to ask for this.
--
-- The stake is spent at the moment the posting is TAKEN, and it is gone whether the run is cleared or
-- lost. That is what makes it a bet rather than a fee.
return {
    name = "Bad Company",
    description = "What is out here is not the usual stock.",

    -- +N to the share of stops allowed to be an elite. Rides params.eliteShare.
    elites = 0.25,

    -- What it pays: a multiplier on the posting's coin.
    gold = 0.4,

    -- What it pays: extra postings put back in hand.
    drops = 1,

    -- WHAT IT COSTS, in the stock the Forge spends -- so making a run richer is priced against the
    -- upgrade you were saving for.
    cost = {
        material_steel_ingot = 2,
    },
}
