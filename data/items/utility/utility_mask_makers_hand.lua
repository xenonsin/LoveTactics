-- THE MASK-MAKER'S HAND: the Mask-Maker's organ (data/characters/character_mask_maker.lua). Reviewed 2026-10-01..03
-- ("Envy's Bestiary"). Its hand is a company's four faces; at the start of its turn it hands every Faceless within 3
-- one of them, all different, and its death hands them back to Reshape (trait_the_mask_maker, models/masks.lua).
return {
    name = "The Mask-Maker's Hand",
    description = "At the start of your turn, each Faceless ally within 3 wears a face you choose: shield, healer, archer, caster.",
    flavor = "It has never worn a face it made. It says they are for the others, and the others believe it.",
    sprite = "assets/items/utility_mask_makers_hand.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_mask_maker" },
}
