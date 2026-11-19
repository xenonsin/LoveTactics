-- THE LONGFANG'S HUNT: the pride leader's rule, carried as creature kit (data/traits/trait_the_longfangs_hunt.lua).
-- Until 2026-11-19 it kept HER hidden after a kill (The Unbroken Stalk, her drop); the creature identity pass
-- split her from the Sabertooth, so she no longer hides and the rule is lent to her pride instead: a cat
-- within three tiles of her that downs a body from hiding stays hidden into its next turn. The company's
-- version is still The Unbroken Stalk -- the same trick, worn by one person on themself.
return {
    name = "The Longfang's Hunt",
    description = "An ally within 3 tiles that downs a foe while Invisible stays Invisible, into its next turn.",
    flavor = "The pride eats where it kills. She has already gone.",
    sprite = "assets/items/utility_the_longfangs_hunt.png",
    type = "utility",
    class = "creature",
    tags = { "beast" },
    noSteal = true,
    traits = { "trait_the_longfangs_hunt" },
}
