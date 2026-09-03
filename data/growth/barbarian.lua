-- Per-level stat gains for a character growing as a barbarian (fighter discipline).
-- Rage: glass-cannon fighter -- more damage than the base line, thinner defence.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/class.lua's growthClasses), so a build leaning on barbarian stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    health = 3, damage = 5, stamina = 3,
}
