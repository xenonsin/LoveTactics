-- The Anchorhold: the Alraune Anchoress's cell, and the two rules she is walled into it with.
--
-- The Pit Grows (trait_the_pit_grows): a death within three tiles of her sprouts a Mandrake where the
-- body fell, on any side, and the sprout goes back into the floor when she does. And Nothing to Hold
-- (trait_nothing_to_hold, the Wind Elemental's): she cannot be shoved, dragged or thrown. An anchoress is
-- sealed into a church wall, and nothing moves her out of it -- which is also why a company fighting
-- her has to go to her, through the garden.
--
-- Bound: it is the elite's own rule list, not a relic she carries (docs/bestiary.md).
return {
    name = "The Anchorhold",
    description = "Deaths near her sprout Mandrakes. She cannot be moved.",
    flavor = "The rite for walling a woman into a church is the same as the rite for burying one. They only read it faster.",
    sprite = "assets/items/the_anchorhold.png",
    type = "utility",
    class = "creature",
    tags = { "relic" },
    bound = true,
    traits = { "trait_the_pit_grows", "trait_nothing_to_hold" },
}
