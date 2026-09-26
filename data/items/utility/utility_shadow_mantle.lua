-- THE SHADOW MANTLE: the Thing Under the Seam's second trophy (character_deep_bane), approved on review
-- 2026-09-26, round 5. A cloak of its shadow: the bearer cannot be targeted by anything farther than three
-- tiles away (trait_shadow_mantle), so the archers and the casters have to come within three to reach
-- them. The thing's own shape of fight, worn -- it made a company close on it, and this makes a company's
-- enemies close on you.
--
-- A UTILITY, NOT A COAT. It is worn over armour rather than instead of it, which is what the fiction says
-- and what keeps it off the movement economy every armour is priced against (tests/armor_spec.lua): the
-- shadow costs no square of pace, and a mantle that did would be a worse cloak for the one body it is
-- for, the one standing at the back.
--
-- ON THE ASSASSIN'S RACK, whose whole shelf works by not being a legal target (Stillshade, the Greyveil
-- Cloak). Unlike either it is never OFF -- and unlike either it never hides you from a blade. Undone by
-- light, as every concealment is.
--
-- A trophy: `unstocked`, on the rack and never sold (tests/discovery_spec.lua's TROPHIES).
return {
    name = "Shadow Mantle",
    description = "You cannot be targeted from more than 3 tiles away.",
    flavor = "It was cast by something standing in a fire. It has kept the shape, and none of the light.",
    sprite = "assets/items/utility_shadow_mantle.png",
    type = "utility",
    tags = { "dark" },
    class = "assassin",
    -- One past the Whip, which is the rarity order the body's drop list reads in (docs/drops.md). The
    -- grader reads 4: it cannot see a flag that stops a whole class of shot (Grade.TRAIT_GRADE's 1.5).
    unlockLevel = 7,
    unstocked = true,
    traits = { "trait_shadow_mantle" },
}
