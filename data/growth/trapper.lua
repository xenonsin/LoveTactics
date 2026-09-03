-- Per-level stat gains for a character growing as a trapper (hunter discipline).
-- Hidden traps: patient, so deep stamina and health over raw damage.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/class.lua's growthClasses), so a build leaning on trapper stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    damage = 2, stamina = 5, health = 3,
}
