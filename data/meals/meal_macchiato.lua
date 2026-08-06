-- Attack Up, S. One of the three opening orders, and the one a party with nothing else to decide
-- should place: damage is the only course every member of every company can spend, which is exactly
-- why the dish is the plainest thing the counter pours. Everybody drinks the coffee.
--
-- The name is doing a little work. A macchiato is a shot MARKED -- stained with a spoonful of milk --
-- and it is small, strong and drunk standing up. That is the shape of this order: not a meal you sit
-- down to, just a mark on the company on the way past.
--
-- Sized at a single charm's worth (+2) on purpose. A meal is worn by four bodies at once and costs no
-- grid cell, so it must not be priced as if it were a fourth item -- see docs/meals.md on why the
-- courses sit one rung below what the same number buys on a shelf.
return {
    name = "Macchiato",
    description = "The whole company strikes harder for the quest.",
    flavor = "A shot marked with a spoonful of milk, drunk standing at the counter by people who have somewhere to be.",
    price = 60,
    unlockPrestige = 1,
    bonus = { damage = 2 },
}
