-- The Unyielding Seal: the wax the Bastion presses on an order it does not intend to revisit. Grants
-- Unyielding (data/traits/trait_unyielding.lua) -- pay mana, and the affliction that just landed comes
-- off, as often as the pool allows.
--
-- The knight's answer to a fight it is losing on statuses rather than on damage. Everything else on
-- this shelf argues about where blows land; this argues about whether the thing that landed gets to
-- stay. Sits well beside the Cleansing Ward for a bearer who can afford both -- the Ward eats the
-- first one free and the Seal buys the rest -- and beside nothing at all for a bearer with no mana,
-- which is a real way to waste a cell.
return {
    name = "Unyielding Seal",
    description = "Spend mana to shrug off any debuff the moment it lands.",
    flavor = "Pressed once, filed twice, and never read again. The order stands because nobody may unmake it.",
    sprite = "assets/items/utility_unyielding_seal.png",
    type = "utility",
    tags = { "charm" },
    class = "knight",
    price = 340,
    repRank = 3,
    traits = { "trait_unyielding" },
}
