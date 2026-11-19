-- PENT UP: what makes the Goblin Brute a Brute. Approved 2026-09-26 ("The Goblins of Wrath"), pitched after
-- Keno's note that a trigger may repeat on a floor "if the payoff is unique". (Named Pent Up, not Short Fuse:
-- that is Pol's signature relic, data/items/utility/utility_short_fuse.lua.)
--
-- A FIXED CHARGE SINCE 2026-11-19 (the creature identity pass; trait_pent_up has the whole account). It opens the
-- fight Primed and bursts as fire on every tile within one when it dies, for the same damage however it was
-- worn down. It used to bank Seething per hit taken, which was the fourth "chipping it charges it" body on Wrath's
-- floors; the lever is now where it dies, not how often it was struck. Bound and unstealable: an organ, not kit --
-- the drop is Bottled Rage, the burst put under the bearer's control.
return {
    name = "Pent Up",
    description = "Primed from the start. On death, deals 24 damage to everything adjacent and sets it alight.",
    flavor = "Every blow went in years ago. None of it has come out yet.",
    sprite = "assets/items/utility_pent_up.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_pent_up" },
}
