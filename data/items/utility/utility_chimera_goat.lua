-- THE CHIMERA'S GOAT, as the piece of its grid that grows it (`head`, Combat.spawnHeads). Creature kit:
-- the goat is a head of its own at the bell, with its own turn and its own breath
-- (character_chimera_goat). Its person's twin is utility_goat_head, on the Beastmaster's shelf.
return {
    name = "The Goat",
    description = "Grows a goat's head that takes its own turns, breathing fire.",
    flavor = "It has opinions about the lion. It keeps them to itself.",
    sprite = "assets/items/utility_chimera_goat.png",
    type = "utility",
    class = "creature",
    tags = { "beast", "head" },
    noSteal = true,
    head = "character_chimera_goat",
}
