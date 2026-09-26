-- HELD IN TRUST: the Lure's one death, kept for it by Vesh (data/characters/character_the_lure.lua).
-- Reviewed 2026-09-25/26 ("The Paymaster"): "Vesh's Bone-Knit so it stands up ONCE from a lethal blow".
--
-- VESH'S RULE, NOT A COPY OF IT. This carries the same trait as his Last Rite (data/traits/trait_bone_knit.lua):
-- a blow that would fell the bearer is refused and it stands back up WHOLE. What differs is the toll, and
-- `traitParams` is the seam for exactly that (models/trait.lua's Trait.param): `cost = false` takes the mana
-- price off, and a Bone-Knit with no price falls back to the once-a-battle latch Trait.trySurvive keeps for
-- an unpriced refusal (tests/skeleton_spec.lua's REGRESSION case). So the shade gets up once, and its blue
-- bar stays the Grave-Chill's.
--
-- Bound and noSteal: an organ, not kit. It is what the shade IS on loan.
return {
    name = "Held in Trust",
    description = "The first blow that would fell you is refused, and you stand back up at full health. Once a fight.",
    flavor = "Vesh keeps one death back for each of his hands. He has never once been asked to give one up.",
    sprite = "assets/items/utility_held_in_trust.png",
    type = "utility",
    tags = { "dark" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_bone_knit" },
    traitParams = { cost = false, revivesLine = "%s is not finished: something below holds its death in trust." },
}
