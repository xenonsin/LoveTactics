-- The tallow hound's own hide, and the vessel Engorge rides in.
--
-- A creature's rule has to live on an ITEM in its grid, because a blueprint's own `traits` field is
-- never collected -- only an item's is (models/trait.lua). That is the same reason each of the seven
-- generals is a relic plus a weapon rather than a stat block with a rule written on it.
--
-- Natural kit, so: no class, no price, noSteal, outside every shelf (tests/bestiary_spec.lua). A hound
-- is not an Alchemist; a hound is what one made.
return {
    name = "Rendered Hide",
    description = "Whenever anything falls nearby, it feeds and heals.",
    flavor = "Something rendered it down and it did not finish the job. What is left has opinions about food.",
    sprite = "assets/items/rendered_hide.png",
    type = "utility",
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_engorge" },
}
