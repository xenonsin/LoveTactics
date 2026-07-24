-- Per-level stat gains for a character growing as a monk (priest discipline).
-- Chi: unarmed strikes are PHYSICAL, so the one priest path that grows damage, not magicDamage.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/discipline.lua's growthClasses), so a build leaning on monk stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    health = 3, damage = 3, stamina = 4, magicDefense = 1,
}
