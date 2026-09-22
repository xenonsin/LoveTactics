-- HERD WARMTH: the reason The Herd is not four copies of the road fight.
--
-- The whole of this file is data/traits/trait_herd_warmth.lua attached to an animal: while any ally is
-- standing beside it, the bearer heals a little every tick, and standing alone it heals not at all.
--
-- IT IS THE MEANDERING STAG'S PREMISE ARRIVING BY THE OPPOSITE VERB, which is the only way a lesser
-- version of that animal is worth having. The apex is the enemy HEALER -- the one support body in this
-- bestiary -- and it heals by WALKING: its trail is unsided New Growth and laying it is the entire
-- first half of that fight (data/items/utility/utility_what_the_wood_owes_it.lua). This one heals by
-- STANDING, it heals only itself, and it leaves no ground at all. Nothing here is borrowed except the
-- family's reason for existing.
--
-- SO IT CHANGES THE ONE ENCOUNTER THIS BODY IS LEFT IN. data/encounters/encounter_the_herd.lua fields
-- three or four, and gets the thing it never had -- a shape. Break them apart, or put one down before
-- the rest close on it.
--
-- THERE WAS A SECOND STAG STOP AND IT IS DELETED. A lone animal on the road, fielding the same cast at
-- a different count, which is one fight met twice rather than two fights. This rule is what made the
-- cut free: paying only in company, it was worth exactly nothing there, so nothing on this file went
-- with it.
--
-- NO `class`/`price`: it is not crafted or sold, only born with. It sits in the loadout of a herd
-- animal the way a signature relic sits in a hero's -- innate, not bought (docs/bestiary.md).
--
-- The player's half of it is utility_the_close_herd, which grants the same trait off a real shelf --
-- the same split data/items/utility/utility_feral_instinct.lua and the Reprisal Quiver already are,
-- and for the same reason: a rule is not a body part, so it can be learned even though the animal
-- carrying it cannot be looted.
return {
    name = "Herd Warmth",
    description = "Heals a little health each tick while another of its kind stands beside it.",
    flavor = "Alone it is meat. Together they are a wall with legs, and they know which one they are.",
    sprite = "assets/items/herd_warmth.png",
    type = "utility",
    class = "creature",
    tags = { "beast" },
    noSteal = true, -- standing with your own kind is not a trinket a pickpocket can lift
    traits = { "trait_herd_warmth" },
}
