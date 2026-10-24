-- UNCOMMON. The Heavy Pack turned inside out: everything that weighs anything is left at the stair, and
-- the company outruns its own armour. A step of walk for two points of defense.
--
-- BOTH HALVES LADDER, and the gain is CAPPED (`bonusCap`, models/relic.lua): +3 movement at three copies
-- is a company that chooses every fight it takes, and a fourth tile on top would make the board's
-- distances stop meaning anything. The defense price keeps climbing past the cap, so a fourth copy is a
-- decision the card states the price of -- it simply buys nothing more to walk with.
return {
    name = "The Bare Feet",
    blurb = "+%d movement for the whole company.",
    tier = "uncommon", mark = "Bf",
    cost = "-%d defense.",
    costScale = { 2, 1 },
    -- The card reads the capped figure, so a fourth copy's card does not promise a tile it will not pay.
    scale = function(n) return math.min(3, n) end,
    bonus = { movement = 1, defense = -2 },
    bonusStep = { movement = 1, defense = -1 },
    bonusCap = { movement = 3 },
}
