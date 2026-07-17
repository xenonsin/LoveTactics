-- Drunken Fist: the sloppier the stance, the heavier the blow. A passive "fist" charm that adds damage
-- to the bearer's bare-handed strike ONLY while it is Drunk (data/status/drunk.lua) -- the bonus is
-- keyed off the drunk flag in the unarmed damage path (models/combat.lua). Pair it with Wine: get
-- drunk, and your punches turn savage; sober up, and it does nothing. A gambler's charm.
return {
    name = "Drunken Fist",
    description = "While Drunk, your bare-handed strike hits far harder. Sober, it does nothing.",
    flavor = "A gambler's charm, sold by a priest who has made his peace with the arrangement.",
    sprite = "assets/items/drunken_fist.png",
    type = "utility",
    tags = { "fist" },
    class = "priest",
    price = 200,
    repRank = 2,
    unarmedBonus = { drunkDamage = { 6, 7, 7, 8, 8, 9, 10, 10, 11, 11, 12 } },
}
