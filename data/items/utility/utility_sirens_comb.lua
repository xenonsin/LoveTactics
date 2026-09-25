-- THE SIREN'S COMB: one of the Siren's own (data/characters/character_siren.lua). Her hearing rule, worn:
-- sound carries over water, so the bearer's abilities reach a Wet foe from two tiles further
-- (trait_sirens_comb, read by Combat.reachWaiver). A piece for a company that soaks.
--
-- `unstocked`: visible on the Cathedral's rack and never sold (docs/drops.md).
return {
    name = "Siren's Comb",
    description = "Your abilities reach Wet foes from 2 tiles further.",
    flavor = "Pearl, and older than the pearl. She was combing her hair when they found her, and she did not stop.",
    sprite = "assets/items/utility_sirens_comb.png",
    type = "utility",
    tags = { "offensive" },
    class = "priest",
    unlockLevel = 3,
    unstocked = true,
    traits = { "trait_sirens_comb" },
}
