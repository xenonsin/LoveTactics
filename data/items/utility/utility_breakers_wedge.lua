-- Breaker's Wedge: the knight half of the Vanguard (knight x rogue), and the discipline's keystone.
-- Every shove the bearer throws also Sunders the body it moved.
--
-- This item replaced a mace that knocked back and Sundered, and the reason is the family contract: the
-- mace archetype ALREADY knocks back two tiles, innately, because that is what a mace is
-- (docs/weapons.md -- "you buy the displacement, not the damage"). A discipline weapon whose pitch is
-- "it shoves" would have been selling the family back to itself. So the shove stays where it lives and
-- the discipline sells the clause on top of it.
--
-- The result is a charm with far more reach than the weapon would have had: 19 items in the catalog
-- cause knockback and only five apply Sundered, so this one cell converts a third of the armed shelf
-- into a Vanguard's breach -- an iron mace, Push, Shieldbreak, a body hurled by Heave, all of it.
-- Stripped Plate is what collects on it.
return {
    name = "Breaker's Wedge",
    description = "Every shove you throw also Sunders the body it moved.",
    flavor = "The gate did not need to be cut. It needed to be encouraged, once, in the right direction.",
    sprite = "assets/items/utility_breakers_wedge.png",
    type = "utility",
    tags = { "charm" },
    class = "knight",
    discipline = "vanguard",
    price = 320,
    unlockQuests = 4,
    traits = { "trait_breakers_wedge" },
}
