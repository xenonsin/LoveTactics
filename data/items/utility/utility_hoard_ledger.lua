-- THE HOARD-LEDGER: the book Avaritia never needed and kept anyway (reviewed 2026-09-25, round 3,
-- "Avaritia, the Unspent"). What the company holds becomes what it hits with (data/traits/
-- trait_hoard_ledger.lua): +2 Damage per 100 gold, up to +10.
--
-- A general's find: `unstocked`, on the mammonite's rack (the house whose weapon is its purse).
return {
    name = "Hoard-Ledger",
    description = "Increase damage by 2 per 100 gold the company holds (up to 10).",
    flavor = "Every page is the same figure, written out again, in a hand that never once shook.",
    sprite = "assets/items/utility_hoard_ledger.png",
    type = "utility",
    tags = { "guile" },
    class = "mammonite",
    unlockLevel = 6,
    unstocked = true,
    traits = { "trait_hoard_ledger" },
}
