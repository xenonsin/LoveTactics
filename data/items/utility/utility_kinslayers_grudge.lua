-- THE KINSLAYER'S GRUDGE: the Kinslayer's organ (data/characters/character_the_kinslayer.lua), carrying his two rules
-- (models/kinslayer.lua): he hunts the favoured one, and whoever lands his killing blow takes 7 times his last
-- hit. `traitParams.measure` turns The Mark's reading from the felling blow (the duelist's drop) to his own last
-- hit. Creature kit: bound, unstealable, on no shelf.
return {
    name = "The Kinslayer's Grudge",
    description = "Hunts the foe healed or blessed most this fight. Its killer takes 7 times its last hit.",
    flavor = "His offering was refused. He has been keeping count of everyone else's ever since.",
    sprite = "assets/items/utility_kinslayers_grudge.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_favoured", "trait_the_mark" },
    traitParams = { measure = "lastHit" },
}
