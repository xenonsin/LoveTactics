-- Per-level stat gains for a character growing as a duelist (fighter x rogue discipline).
-- Duel stance: 1v1 burst -- rogue speed on a fighter's swing.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/discipline.lua's growthClasses), so a build leaning on duelist stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    speed = 2, damage = 4, stamina = 3, health = 1,
}
