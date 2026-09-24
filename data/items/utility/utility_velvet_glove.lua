-- THE VELVET GLOVE: what comes off a velvet slime (data/characters/character_velvet_slime.lua), and the
-- only place it comes from. Its Strip, worn -- once a battle, the first foe you hit in melee loses its
-- armour for the fight (trait_velvet_glove).
--
-- `unstocked`: visible on the Cathedral's rack and never sold (docs/drops.md).
return {
    name = "Velvet Glove",
    description = "Your first melee weapon hit each battle strips the target's armour off for the fight.",
    flavor = "It asks so nicely that the buckles undo themselves.",
    sprite = "assets/items/utility_velvet_glove.png",
    type = "utility",
    tags = { "offensive" },
    class = "priest",
    unlockLevel = 3,
    unstocked = true,
    traits = { "trait_velvet_glove" },
}
