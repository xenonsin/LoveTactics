-- THE DROWSE: Desidia's organ for the cold around her (data/characters/character_general_sloth.lua;
-- data/traits/trait_the_drowse.lua). Every body that took a turn in her round and did not move gains Drowsy, either
-- side. Creature kit: bound, unstealable, on no shelf -- Lull, her warden's drop, is the same stillness turned on foes.
return {
    name = "The Drowse",
    description = "At the end of each round, every body that took a turn and did not move gains Drowsy.",
    flavor = "The cold does not bite. It waits for you to stop, and then it is kind.",
    sprite = "assets/items/utility_the_drowse.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_drowse" },
}
