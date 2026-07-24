-- Per-level stat gains for a character growing as a crusader (fighter x priest discipline).
-- Smite: a holy blade -- fighter's damage carrying a priest's light.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/discipline.lua's growthClasses), so a build leaning on crusader stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    health = 4, damage = 3, magicDamage = 2, mana = 2,
}
