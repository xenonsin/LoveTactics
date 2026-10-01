-- THREE WISHES: the Wishmaker's organ (trait_three_wishes). Reviewed 2026-09-30 ("Pride's Bestiary").
--
-- While her Lamp stands, it grants a wish at each third of her health: at two-thirds she is whole again, at
-- one-third she takes the company's strongest boon, and at the blow that would fell her she becomes a Great
-- Djinn that cannot be killed until the Lamp breaks. The rule is in models/djinn.lua. Bound and unstealable.
return {
    name = "Three Wishes",
    description = "While your Lamp stands, it grants a wish at each third of your health.",
    flavor = "She found the lamp, and then she found out it would not answer to anybody else.",
    sprite = "assets/items/utility_three_wishes.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_three_wishes" },
}
