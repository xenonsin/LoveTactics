-- PAY OUT: the Paymaster's purse, worn as part of the disguise (data/characters/character_the_paymaster.lua).
-- Reviewed 2026-09-25/26 ("The Paymaster"). At the start of each of his turns a coin heap lands on an open
-- tile within 2 of a living dwarf of his crew (trait_pay_out -> status_pay_out -> models/paymaster.lua), and
-- the crew goes for it: every heap is a stack of Dragon-Sickness walking toward somebody, and three of them
-- make a Gilt Wyrm.
--
-- Bound and noSteal: this is what he is FOR, not a thing he carries. A thief's hand finds no purse on him,
-- which is also true of the dwarves -- but they are unrobbable because of Stout, and he is because there is
-- nothing in it but what he throws away.
return {
    name = "Pay Out",
    description = "At the start of your turn, a heap of gold lands within 2 of a dwarf of your crew.",
    flavor = "Honest wages, and more than honest. Nobody who takes them ever asks where the paymaster came up from.",
    sprite = "assets/items/utility_pay_out.png",
    type = "utility",
    tags = { "earth" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_pay_out" },
}
