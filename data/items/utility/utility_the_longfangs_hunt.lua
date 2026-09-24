-- THE LONGFANG'S HUNT: the alpha's rule, carried as creature kit. A pounce that downs its mark leaves her
-- Invisible, and she opens her next turn Invisible (data/traits/trait_the_unbroken_stalk.lua) -- so she
-- takes a body a turn and is never once seen. The company's version is The Unbroken Stalk, the same trait.
return {
    name = "The Longfang's Hunt",
    description = "A blow struck while Invisible that downs its target keeps you Invisible, into your next turn.",
    flavor = "The pride eats where it kills. She has already gone.",
    sprite = "assets/items/utility_the_longfangs_hunt.png",
    type = "utility",
    class = "creature",
    tags = { "beast" },
    noSteal = true,
    traits = { "trait_the_unbroken_stalk" },
}
