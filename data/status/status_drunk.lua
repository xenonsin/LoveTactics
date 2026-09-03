-- Drunk: liquid courage. The reckless swagger hits harder but drops the guard -- more Damage, less
-- defense of either school. It is NOT a debuff (Cure won't strip it): being drunk is a bargain the
-- player struck on purpose, and it is the flag Drunken Fist reads to pour extra Power into a bare
-- punch (see the unarmed damage path in models/combat.lua). Applied by Wine (data/items/consumable).
return {
    name = "Drunk",
    abbr = "Drk",
    description = "Reckless: +3 Damage, but -3 defense, -3 magic defense and -3 Skill.",
    color = { 0.753, 0.463, 0.711 }, -- badge tint (wine purple)
    duration = 24,                 -- a good while: several turns of swagger
    -- THE SKILL CUT IS THE COST THE BARGAIN WAS MISSING. Drunk swapped guard for power and said nothing
    -- about the one thing drink actually does to a fighter, because until accuracy there was no stat for
    -- it. Swing harder, connect less: that is the trade the flavour was always describing.
    --
    -- It deliberately sharpens a bargain that already shipped rather than leaving it alone. The reason
    -- is that the Crucible sells both ends of this now -- the wine that costs you aim, and the shelf
    -- that sells it back -- so the house argues with itself, which is what an envy shelf should do.
    -- Drunken Fist is unaffected: it reads the FLAG, not the stats, and pours its bonus into a bare
    -- punch regardless.
    statBonus = { damage = 3, defense = -3, magicDefense = -3, skill = -3 },
}
