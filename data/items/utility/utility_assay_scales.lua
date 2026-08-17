-- The assayer's scales, and the vessel Assayed rides in.
--
-- Natural kit: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "Assay Scales",
    description = "Gains damage for the coin its foes are carrying.",
    flavor = "It weighed the party before they came through the door, and found them worth the trouble.",
    sprite = "assets/items/assay_scales.png",
    type = "utility",
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_assayed" },
}
