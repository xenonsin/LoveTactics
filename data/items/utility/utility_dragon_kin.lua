-- DRAGON-KIN: the kobold beastmaster's race item ("The Rift's Adventurers", slice D, approved 2026-10-09). A
-- creature the bearer summoned counts as a dragon on its side (trait_dragon_kin, Devotion.isDragon), so every
-- kobold near it -- the bearer first -- fights under the Dragon's Eye. A kobold that cannot find a god raises one.
--
-- Gated to kobolds (Character.canCarry). No price: a rift find on the beastmaster's shelf at the class's floor.
return {
    name = "Dragon-Kin",
    description = "Your bonded beast counts as a dragon on your side.",
    flavor = "The wolf has no idea what it is being worshipped for, and has stopped asking.",
    sprite = "assets/items/utility_dragon_kin.png",
    type = "utility",
    tags = { "beast" },
    class = "beastmaster",
    race = "kobold",
    unlockLevel = 3,
    traits = { "trait_dragon_kin" },
}
