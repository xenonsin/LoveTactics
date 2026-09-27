-- THE HORNED SISTER: the Horned Twin's half of the Oni Twins' pair rule. Approved 2026-09-26/27 ("The Oni of
-- Wrath"), after Re:Zero's twins, one horned and one not.
--
-- Whenever her sister is struck she goes Horn Out at once (trait_the_hornless_sister raises it; this flag is what
-- it looks for), and if her sister falls she goes FULL Horn Out for the rest of the fight (status_full_horn_out):
-- her flail sweeps every foe within 3 and she heals a fifth of her health each turn. Bound and unstealable.
return {
    name = "The Horned Sister",
    description = "When your sister is struck, Horn Out. When she falls, Full Horn Out for the rest of the fight.",
    flavor = "She was born with the horn. She has spent her life deciding what it is for.",
    sprite = "assets/items/utility_the_horned_sister.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_horned_sister" },
}
