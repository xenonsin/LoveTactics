-- THE LABYRINTH: the Minotaur's organ (trait_the_labyrinth; models/labyrinth.lua). The maze it fights in, the
-- walls it walks through, the walls that slide, and the head that goes down.
return {
    name = "The Labyrinth",
    description = "Fights in a maze it walks through. Every third turn the walls slide. Below a third of its health, it goes into Fury.",
    flavor = "A house with no doors, built for one.",
    sprite = "assets/items/utility_the_labyrinth.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_labyrinth" },
}
