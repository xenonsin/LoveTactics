-- Per-level stat gains for a character growing as a poisoner (alchemist discipline).
-- Coatings: applied between swings, so a point of stamina joins the alchemist's magic.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/discipline.lua's growthClasses), so a build leaning on poisoner stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    magicDamage = 3, mana = 4, stamina = 2, health = 3, -- survivability floor (Growth.ENEMY_DAMAGE_GROWTH)
}
