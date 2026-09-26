-- THE PAYROLL: the Paymaster's book, and the whole of his disguise's ending (data/characters/
-- character_the_paymaster.lua; trait_the_payroll; models/paymaster.lua). Reviewed 2026-09-25/26 ("The
-- Paymaster").
--
-- WORDED TO HOLD UNTIL IT DOES NOT. What the company can read off his grid before the reveal is that the
-- account is settled when the last of the crew falls -- which is true, and says nothing about who settles
-- it. The last crewman down turns him into the Lure, and the crew that fell gets back up on his side.
--
-- Bound and noSteal: it is the disguise's own rule, not a ledger a thief could lift.
return {
    name = "The Payroll",
    description = "When the last dwarf of your crew falls, the account is settled.",
    flavor = "Every name in a neat hand, and a column headed DUE that nobody on the list ever reads.",
    sprite = "assets/items/utility_the_payroll.png",
    type = "utility",
    tags = { "dark" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_payroll" },
}
