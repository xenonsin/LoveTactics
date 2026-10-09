-- HYDRA'S BLOOD: one of the Lernaean Hydra's three trophies, on the Poisoner's shelf. Approved 2026-10-09 ("The
-- Crown's Bestiary", slice E). The bile Heracles dipped his arrows in: every weapon blow Poisons, and a Poisoned foe
-- that falls passes it to every foe beside it (trait_hydras_blood, models/lerna.lua).
--
-- Contagion (the Plague Knight's) spreads Poison every turn from a living body; this spreads it once, from a dead
-- one. Same noun, different trigger and different payoff.
--
-- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
return {
    name = "Hydra's Blood",
    description = "Your blows Poison. When a Poisoned foe falls, its Poison spreads to every foe beside it.",
    flavor = "A drop on the arrowhead. The centaur it killed was not even the one he was aiming at.",
    sprite = "assets/items/utility_hydras_blood.png",
    type = "utility",
    tags = { "charm", "poison" },
    class = "poisoner",
    unlockLevel = 15,
    unstocked = true,
    traits = { "trait_hydras_blood" },
}
