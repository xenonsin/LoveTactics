-- THE LEDGER COIN: Greed's slime rule, worn (data/characters/character_slime.lua). The slime compounds
-- (trait_interest); so does the bearer -- each of their turns in a fight, one more Damage, up to six. No
-- purse on this one: the coin is the principal, not the payout.
--
-- `unstocked`: the slime's own piece, visible on the Undercroft's rack and never sold (docs/drops.md).
return {
    name = "Ledger Coin",
    description = "Each of your turns in a fight: +1 Damage, up to +6.",
    flavor = "Heads, it grows. Tails, it grows.",
    sprite = "assets/items/utility_ledger_coin.png",
    type = "utility",
    tags = { "offensive" },
    class = "rogue",
    unlockLevel = 5,
    unstocked = true,
    traits = { "trait_interest" },
    traitParams = { interestStep = 1, interestGold = 0, interestCap = 6 },
}
