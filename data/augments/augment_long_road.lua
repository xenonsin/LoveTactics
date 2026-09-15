-- The Long Road -- an augment (models/augment.lua): a danger staked on a bounty before it is taken.
--
-- Length rather than difficulty, and the two are genuinely different bets: a longer road is not
-- harder per fight, it is harder to arrive at the end of with anything left -- which is what
-- the wound ladder measures (models/wound.lua). It pays in postings, because what a long day
-- out produces is more work to choose from.
--
-- The stake is spent at the moment the posting is TAKEN, and it is gone whether the run is cleared or
-- lost. That is what makes it a bet rather than a fee.
return {
    name = "The Long Road",
    description = "Three more stops before the thing you came for.",

    -- +N stops on the way. Rides map.encounters.
    fights = 3,

    -- What it pays: extra postings put back in hand.
    drops = 1,

    -- WHAT IT COSTS, in the stock the Forge spends -- so making a run richer is priced against the
    -- upgrade you were saving for.
    cost = {
        material_iron_scrap = 2,
    },
}
