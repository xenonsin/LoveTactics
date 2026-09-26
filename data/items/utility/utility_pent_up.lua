-- PENT UP: what makes the Goblin Brute a Brute. Approved 2026-09-26 ("The Goblins of Wrath"), pitched after
-- Keno's note that a trigger may repeat on a floor "if the payoff is unique". (Named Pent Up, not Short Fuse:
-- that is Pol's signature relic, data/items/utility/utility_short_fuse.lua.)
--
-- The trigger is Ira's and the Caldera King's: every hit it takes adds Seething (the existing status, more
-- Damage per stack). The payoff is its own: when it dies, the stacks BURST AS FIRE on every tile within one,
-- with more damage per stack (trait_pent_up). From three stacks it wears Primed, so the company can see the
-- bomb it is building. Bound and unstealable: an organ, not kit -- the drop is Bottled Rage, the burst put
-- under the bearer's control.
return {
    name = "Pent Up",
    description = "Each hit taken adds Seething. On death, deals 6 plus 6 per stack to everything adjacent and sets it alight.",
    flavor = "Every blow goes in and none of it comes out. Until it all does.",
    sprite = "assets/items/utility_pent_up.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_pent_up" },
}
