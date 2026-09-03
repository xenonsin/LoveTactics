-- The hollow sleeper's weight, and the vessel Torpor rides in.
--
-- A creature's rule lives on an ITEM in its grid -- a blueprint's own `traits` field is never collected
-- (models/trait.lua). Natural kit: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "Sleeper's Weight",
    description = "Swears two foes together as it acts. Each one that ends its turn apart is bitten.",
    flavor = "It stopped keeping watch a long time ago. It never stopped being on it.",
    sprite = "assets/items/sleepers_weight.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_torpor" },
}
