-- The Odds Against: the Champion's charm for being outnumbered on purpose. Carries
-- trait_against_the_odds -- defense and speed for every enemy standing beside the bearer, counted
-- fresh at every moment rather than banked when the fight opened.
--
-- WHY THE CHAMPION'S. Fighter x knight is the discipline that answers "what happens when you are the
-- one they all come at": Defiant Stand banks a pool off being hit, Crowd's Favour widens that pool to
-- the rank, Reprisal answers a blow with a blow. All three pay for being struck. This pays for being
-- SURROUNDED, which is the setup rather than the outcome -- it is worth something on the turn you wade
-- in, before anybody has swung at you at all. That is the gap on the shelf.
--
-- It pairs with the Colosseum's own doctrine and against the Bastion's: a knight wants a doorway so
-- only one of them can reach it, and this wants the open floor with all four of them on it. Buying
-- both is a contradiction the player is welcome to build; what they will find is that the charm goes
-- quiet in a corridor, which is the correct lesson and costs nothing to teach.
--
-- The speed half is the one to watch when tuning. Speed is initiative and initiative is the only
-- currency nobody gets back, so a Champion enveloped by four is not merely tougher, it acts markedly
-- more often. That is the intent -- the item exists to make being surrounded a turn you WANT -- but it
-- means the per-enemy figure is a magnitude to move carefully. See the trait for the numbers.
local Curve = require("models.curve")

return {
    name = "The Odds Against",
    description = "Gains defense and speed for each enemy standing beside you, moment to moment.",
    flavor = "Four of them. He counted, the way a man counts change he has been handed rather than owes.",
    sprite = "assets/items/odds_against.png",
    type = "utility",
    tags = { "charm" },
    class = "fighter",
    discipline = "champion", -- deeper cut of the shelf: buyable only once the champion gate is cleared
    price = 245,
    unlockQuests = 2,
    traits = { "trait_against_the_odds" },
    -- A floor, so the cell is not dead in the fights where nobody obliges by surrounding you. Small
    -- on purpose: what is being bought here is the trait, and a generous baseline would let the charm
    -- be worth carrying by a body that never walks into anything.
    bonus = { defense = Curve.ramp(1, 11) },
}
