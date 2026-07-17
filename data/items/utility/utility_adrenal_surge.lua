-- The item that carries Adrenal Surge (data/traits/adrenal_surge.lua): every blow that lands on the
-- wearer pulls their next turn sooner.
--
-- A passive utility whose whole effect is the trait it grants, like the Duelist's Reflex or the
-- Reprisal Quiver beside it on the shelf. Sold by the fighter's vendor -- wrath's line, and there is no
-- better statement of it than a body that answers being hurt by getting there faster (see docs/story.md).
--
-- Note it wants the opposite build from every other defensive item in the game: it pays out when you are
-- struck, so stacking armor until nothing lands turns it off. The fighter who runs this wants to be in
-- the middle of it.
return {
    name = "Rage-Wrought Girdle",
    description = "Every blow you take pulls your next turn sooner.",
    flavor = "Wrath is a kind of speed. Armour it away until nothing lands and you have bought a belt that does nothing.",
    sprite = "assets/items/adrenal_surge.png",
    type = "utility",
    tags = { "belt" },
    class = "fighter",
    price = 340,
    repRank = 2,
    traits = { "trait_adrenal_surge" },
}
