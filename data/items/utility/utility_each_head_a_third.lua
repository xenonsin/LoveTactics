-- EACH HEAD A THIRD: Cerberus's own (data/characters/character_cerberus.lua; "The Crown's Bestiary", slice C). It
-- carries the rule that cuts the bar into the three heads (trait_each_head_a_third): a blow on the body lands on the
-- fullest head, a head at 0 goes quiet, and the last head lost fells the dog.
--
-- `bound`, `noSteal`, `class = "creature"`: a creature's organ is never handed to the player.
return {
    name = "Each Head a Third",
    description = "Its health is its three heads'. A blow on the body lands on the fullest head; a head at 0 goes quiet.",
    flavor = "Kill the dog, said the Sibyl's pupil. Which one, said the Sibyl.",
    sprite = "assets/items/utility_each_head_a_third.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_each_head_a_third" },
}
