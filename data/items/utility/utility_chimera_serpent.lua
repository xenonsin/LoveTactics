-- THE CHIMERA'S SERPENT, as the piece of its grid that grows it (`head`, Combat.spawnHeads), and the bite
-- it throws for the body (trait_serpents_strike -- carried HERE, because the blow it answers lands on the
-- body and a head stands on no tile). Creature kit; its person's twin is utility_serpent_head.
return {
    name = "The Serpent",
    description = "Grows a serpent's head that takes its own turns, and bites the first foe to strike you while coiled.",
    flavor = "The back end of the animal, and the only end that is not hungry.",
    sprite = "assets/items/utility_chimera_serpent.png",
    type = "utility",
    class = "creature",
    tags = { "beast", "head" },
    noSteal = true,
    head = "character_chimera_serpent",
    traits = { "trait_serpents_strike" },
}
