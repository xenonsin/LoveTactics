-- Drunken Fist: the sloppier the stance, the heavier the blow. A passive "fist" charm that adds damage
-- to the bearer's bare-handed strike ONLY while it is Drunk (data/status/drunk.lua) -- the bonus is
-- keyed off the drunk flag in the unarmed damage path (models/combat.lua). Pair it with Wine: get
-- drunk, and your punches turn savage; sober up, and it does nothing. A gambler's charm.
return {
    name = "Drunken Fist",
    description = "While Drunk, your bare-handed strike hits far harder (+6 Power). Sober, it does nothing.",
    sprite = "assets/items/drunken_fist.png",
    type = "utility",
    tags = { "fist" },
    class = "priest",
    price = 200,
    repRank = 2,
    unarmedBonus = { drunkDamage = { 6, 7, 7, 8, 8, 9, 10, 10, 11, 11, 12 } },
}
