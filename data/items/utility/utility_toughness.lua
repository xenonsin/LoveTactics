-- Toughness: a slab of extra constitution. A passive charm that raises the bearer's maximum health for
-- the battle (`maxBonus.health`, folded into Combat.unreservedMax without touching the base stat, so
-- it never compounds between fights). The extra ceiling is headroom to heal into -- wounds carry
-- between battles, so equipping it lifts the cap rather than instantly topping you off.
--
-- Gated one quest later than it used to be. That is the grade ledger's own placement for it
-- (`grade-report diff`), and it keeps the Colosseum's second quest opening a pair of plain rows now
-- that Adrenaline has gone behind the barbarian gate -- a gate that opens one row reads as a shop that
-- did not move (tests/balance_spec.lua).
local Curve = require("models.curve")

return {
    name = "Toughness",
    description = "Raises your maximum health.",
    flavor = "The Colosseum sells constitution by the slab, and has never been short of demand.",
    sprite = "assets/items/toughness.png",
    type = "utility",
    tags = { "charm" },
    class = "fighter",
    price = 80,
    unlockQuests = 0,
    maxBonus = { health = Curve.ramp(20) },
}
