-- Per-level stat gains for a character growing as a warlord (fighter discipline).
-- Banner leadership: a fighter who holds ground, so a point of defence over the base line.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/class.lua's growthClasses), so a build leaning on warlord stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    health = 4, damage = 3, stamina = 3, defense = 1,
}
