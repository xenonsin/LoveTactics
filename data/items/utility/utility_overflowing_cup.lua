-- Overflowing Cup: the Monk's Overflow payoff (docs/engines.md). Every heal the bearer casts past full
-- banks a point of chi, the same bank the monk's fists fill (`charge` on the chi pool, from
-- `overhealBurst`), and spending a FULL bank quickens the next action (trait_overflowing_cup).
return {
    name = "Overflowing Cup",
    description = "Healing past full banks 1 chi. Consuming a full chi bank makes your next action cost 2 less time.",
    flavor = "The Lodge's monks drink from it after the bout, and pour what is left on the sand.",
    sprite = "assets/items/utility_overflowing_cup.png",
    type = "utility",
    tags = { "holy" },
    class = "monk",
    unlockLevel = 8,
    charge = { key = "chi", from = { "overhealBurst" } },
    traits = { "trait_overflowing_cup" },
    bonus = { speed = 1 },
}
