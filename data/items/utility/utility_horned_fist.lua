-- HORNED FIST: the oni monk's race item ("The Rift's Adventurers", slice D, approved 2026-10-09). When the
-- bearer Horns Out, its chi bank fills (trait_horned_fist): the oni's temper and the monk's discipline turn out
-- to be the same quantity, spent all at once.
--
-- Gated to oni (Character.canCarry). No price: a rift find on the monk's shelf at the class's floor.
return {
    name = "Horned Fist",
    description = "When you Horn Out, your chi bank fills.",
    flavor = "The temple meant to teach it to master its anger, and taught it exactly where to keep it.",
    sprite = "assets/items/utility_horned_fist.png",
    type = "utility",
    tags = { "charm" },
    class = "monk",
    race = "oni",
    unlockLevel = 5,
    traits = { "trait_horned_fist" },
}
