-- Per-level stat gains for a character growing as a NOVICE: a point of everything but Move.
-- The blank slate's table (data/classes/novice.lua). Even on purpose: a Novice is not yet anything, so
-- it grows a little of everything rather than leaning. It sits under the survivability floor the rest
-- of the tables are held to (Growth.meetsSurvivabilityFloor) and is exempted by name in
-- tests/growth_spec.lua -- a class you are meant to leave is allowed an expiry date.
return {
    health = 1,
    mana = 1,
    stamina = 1,
    damage = 1,
    magicDamage = 1,
    defense = 1,
    magicDefense = 1,
    speed = 1,
}
