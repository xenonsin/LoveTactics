-- Per-level stat gains for a character growing as a sentinel (knight discipline).
-- Intercept: takes hits for the line, so it grows into both defences.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/discipline.lua's growthClasses), so a build leaning on sentinel stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    damage = 1,
    health = 6, defense = 2, magicDefense = 2, stamina = 1,
}
