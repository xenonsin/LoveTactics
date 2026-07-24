-- Per-level stat gains for a character growing as a exorcist (priest discipline).
-- Banish: anti-magic -- the priest line with a heavier magic defence.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/discipline.lua's growthClasses), so a build leaning on exorcist stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    mana = 5, magicDamage = 2, magicDefense = 3, health = 2,
}
