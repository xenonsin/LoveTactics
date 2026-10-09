-- CERBERUS'S HEAD: one of the dog's three (data/characters/character_cerberus.lua; "The Crown's Bestiary", slice C).
-- A head grown at the bell (`head`, Combat.spawnHeads) the way the Chimera grows its goat and serpent: it stands on no
-- tile, is aimed at through the body's head picker, and dies with the body. Unlike theirs it takes no turn of its own
-- (character_cerberus_head is `timeless`) -- the bites are the body's, one per head awake (weapon_three_mouths).
--
-- Bound and unstealable: a head is the body's, and Cerberus carries three of these.
return {
    name = "Cerberus's Head",
    description = "Grows one of the three heads. Each holds a third of the body's health and bites once a turn.",
    flavor = "Any one of them is a dog. It is the agreement between them that is the problem.",
    sprite = "assets/items/utility_cerberus_head.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    head = "character_cerberus_head",
}
