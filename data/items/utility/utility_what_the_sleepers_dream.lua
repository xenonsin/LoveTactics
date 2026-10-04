-- WHAT THE SLEEPERS DREAM: Desidia's organ for the shades (data/characters/character_general_sloth.lua;
-- data/traits/trait_what_the_sleepers_dream.lua). Each round every sleeping foe dreams a shade of itself onto her
-- side, which lasts until it wakes. Creature kit: bound, unstealable, on no shelf -- the Nightmare Lantern carries the
-- same trait for a necromancer.
return {
    name = "What the Sleepers Dream",
    description = "Each round, every sleeping foe dreams a shade of itself onto her side. It lasts until the sleeper wakes.",
    flavor = "Everyone who has slept on the ice has dreamed of her. She has dreamed back.",
    sprite = "assets/items/utility_what_the_sleepers_dream.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_what_the_sleepers_dream" },
}
