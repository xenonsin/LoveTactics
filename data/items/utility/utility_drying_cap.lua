-- THE DRYING CAP: what makes a Redcap a Redcap (reviewed 2026-09-26, round 2). In the folklore its cap must be
-- kept wet with blood, and if it dries the Redcap dies. So every turn it draws no blood it loses 10% of its
-- health, and a kill wets the cap and heals it 25% (trait_drying_cap). An assassin that has to keep killing.
-- Bound and unstealable: an organ, not kit.
return {
    name = "The Drying Cap",
    description = "Lose 10% of your health at the end of each turn you drew no blood. A kill heals 25%.",
    flavor = "It was red once. It has to be red again by morning.",
    sprite = "assets/items/utility_drying_cap.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_drying_cap" },
}
