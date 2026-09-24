-- DISTENDED GIRTH: the Sated's fight turned around, for the Bulwark (data/traits/trait_distended_girth.lua).
-- You open the fight Full x3 -- +2 Defense and -1 Movement a meal -- and shed one at each quarter of your
-- health you lose, taking a debuff off with it and getting the step back. Approved on review (2026-09-23).
--
-- The coat's own square of pace is the armour contract's (every armour costs one); the meals are on top.
return {
    name = "Distended Girth",
    description = "Open with 3 meals (+2 defense, -1 movement each). Each quarter of health lost sheds one and a debuff.",
    flavor = "Let it out a notch before the fight. You will be taking it in again before the end.",
    sprite = "assets/items/armor_distended_girth.png",
    type = "armor",
    tags = { "hide" },
    class = "bulwark",
    unlockLevel = 4,
    unstocked = true,
    bonus = { defense = 2, movement = -1 },
    traits = { "trait_distended_girth" },
}
