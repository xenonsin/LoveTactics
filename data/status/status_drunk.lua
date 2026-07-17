-- Drunk: liquid courage. The reckless swagger hits harder but drops the guard -- more Damage, less
-- defense of either school. It is NOT a debuff (Cure won't strip it): being drunk is a bargain the
-- player struck on purpose, and it is the flag Drunken Fist reads to pour extra Power into a bare
-- punch (see the unarmed damage path in models/combat.lua). Applied by Wine (data/items/consumable).
return {
    name = "Drunk",
    abbr = "Drk",
    description = "Reckless: +3 Damage, but -3 defense and -3 magic defense.",
    color = { 0.80, 0.45, 0.75 }, -- badge tint (wine purple)
    duration = 24,                 -- a good while: several turns of swagger
    statBonus = { damage = 3, defense = -3, magicDefense = -3 },
}
