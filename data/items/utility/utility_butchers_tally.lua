-- Butcher's Tally: a notched strap the Colosseum's stable hands score once per body carried off the
-- sand, whoever it belonged to. A passive utility (no ability of its own) -- its whole effect is the
-- trait it grants (data/traits/trait_blood_fever.lua): the bearer's Damage climbs with every death on
-- the field, on either side, up to five of them.
--
-- What makes it a wrath item rather than a generic snowball is the indifference. It does not reward
-- killing (data/items/utility/utility_executioners_eye.lua does that) and it does not answer a comrade
-- falling. It rewards the fight going badly for SOMEBODY -- so the bearer's own line breaking is good
-- news to it, which is the sin stated as arithmetic and is exactly what the Colosseum's crowd is for.
--
-- Best carried by whoever is still standing at the end: a slow, armoured fighter that outlives the
-- exchange collects the whole tally, while a duelist that opens the battle with its best swing gets
-- nothing for it. The charm is worthless in the fight you win in two turns.
return {
    name = "Butcher's Tally",
    description = "Every death on the field, either side, raises your Damage for the rest of the battle.",
    flavor = "The stable hands cut a notch per body. They have never once asked whose.",
    sprite = "assets/items/butchers_tally.png",
    type = "utility",
    tags = { "charm" },
    class = "fighter",
    price = 380,
    repRank = 3,
    traits = { "trait_blood_fever" },
}
