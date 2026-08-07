-- Toughness: a slab of extra constitution. A passive charm that raises the bearer's maximum health for
-- the battle (`maxBonus.health`, folded into Combat.unreservedMax without touching the base stat, so
-- it never compounds between fights). The extra ceiling is headroom to heal into -- wounds carry
-- between battles, so equipping it lifts the cap rather than instantly topping you off.
local Curve = require("models.curve")

return {
    name = "Toughness",
    description = "Raises your maximum health.",
    flavor = "The Colosseum sells constitution by the slab, and has never been short of demand.",
    sprite = "assets/items/toughness.png",
    type = "utility",
    tags = { "charm" },
    class = "fighter",
    price = 140,
    unlockQuests = 1,
    maxBonus = { health = Curve.ramp(20) },
}
