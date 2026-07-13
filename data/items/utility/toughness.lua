-- Toughness: a slab of extra constitution. A passive charm that raises the bearer's maximum health for
-- the battle (`maxBonus.health`, folded into Combat.unreservedMax without touching the base stat, so
-- it never compounds between fights). The extra ceiling is headroom to heal into -- wounds carry
-- between battles, so equipping it lifts the cap rather than instantly topping you off.
return {
    name = "Toughness",
    description = "Raises your maximum health by 20.",
    sprite = "assets/items/toughness.png",
    type = "utility",
    tags = { "charm" },
    class = "fighter",
    price = 220,
    repRank = 2,
    maxBonus = { health = { 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40 } },
}
