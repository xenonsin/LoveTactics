-- Per-level stat gains for a character growing as a thief (rogue discipline).
-- Larceny: a working rogue -- speed and stamina to keep striking, modest damage.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/discipline.lua's growthClasses), so a build leaning on thief stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    speed = 2, damage = 2, stamina = 4, health = 3, -- survivability floor (Growth.ENEMY_DAMAGE_GROWTH)
}
