-- THE COMPOUND PURSE: one of the King Slime's own (data/characters/character_king_slime.lua). His purse,
-- worn: each of the bearer's turns in a fight banks 3 gold on it, paid only if the fight is won
-- (Combat.bounty), for at most ten turns. A long fight pays; a lost one pays nothing.
--
-- `unstocked`: visible on the Undercroft's rack and never sold (docs/drops.md).
return {
    name = "Compound Purse",
    description = "Each of your turns in a fight banks 3 gold, paid if you win (up to 30).",
    flavor = "It was never full. It was only ever fuller.",
    sprite = "assets/items/utility_compound_purse.png",
    type = "utility",
    tags = { "utility" },
    class = "rogue",
    unlockLevel = 6,
    unstocked = true,
    traits = { "trait_interest" },
    traitParams = { interestStep = 0, interestGold = 3, interestCap = 10, interestPaysNow = true },
}
