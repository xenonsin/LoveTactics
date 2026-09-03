-- Per-level stat gains for a character growing as a bombardier (alchemist discipline).
-- Scatter bombs: thrown, so stamina over deep mana -- a physical-throw alchemist.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/class.lua's growthClasses), so a build leaning on bombardier stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    magicDamage = 3, mana = 3, stamina = 3, health = 3, -- survivability floor (Growth.ENEMY_DAMAGE_GROWTH)
}
