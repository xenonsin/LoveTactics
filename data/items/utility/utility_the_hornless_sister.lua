-- THE HORNLESS SISTER: the Hornless Twin's half of the Oni Twins' pair rule. Approved 2026-09-26/27 ("The Oni of
-- Wrath").
--
-- She has no horn to draw on, so at the top of each of her turns she draws her mana from her sister
-- (status_borrowed_horn). While the horned twin is down, Silenced or Snapped, she draws nothing and is Silenced
-- herself. When she is struck, her sister's horn comes out. Bound and unstealable.
return {
    name = "The Hornless Sister",
    description = "Draw your mana from your sister each turn; without her, you are Silenced. When you are struck, her horn comes out.",
    flavor = "What she lost was never the horn. It was the need for one.",
    sprite = "assets/items/utility_the_hornless_sister.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_hornless_sister" },
}
