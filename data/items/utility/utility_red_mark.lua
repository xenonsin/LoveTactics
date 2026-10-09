-- RED MARK: the oni assassin's race item ("The Rift's Adventurers", slice D, approved 2026-10-09). One action that
-- both blinks the bearer and fells a foe sends it Horn Out (trait_red_mark): the horn answers a kill made out of
-- nowhere the way it answers a wound.
--
-- Gated to oni (Character.canCarry). No price: a rift find on the assassin's shelf at the class's floor.
return {
    name = "Red Mark",
    description = "A blink to finish a foe sends you Horn Out.",
    flavor = "It paints the mark on before the job, and afterwards nobody can tell the paint from the rest.",
    sprite = "assets/items/utility_red_mark.png",
    type = "utility",
    tags = { "charm" },
    class = "assassin",
    race = "oni",
    unlockLevel = 5,
    traits = { "trait_red_mark" },
}
