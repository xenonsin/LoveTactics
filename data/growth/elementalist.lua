-- Per-level stat gains for a character growing as a elementalist (mage discipline).
-- Sigils: the mage's magic sharpened -- more magicDamage, the same deep mana.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/discipline.lua's growthClasses), so a build leaning on elementalist stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    magicDamage = 4, mana = 5, health = 3, -- survivability floor (Growth.ENEMY_DAMAGE_GROWTH)
}
