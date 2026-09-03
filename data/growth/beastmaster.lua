-- Per-level stat gains for a character growing as a beastmaster (hunter discipline).
-- Bond: commands a beast -- stamina and health to outlast, steady damage.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/class.lua's growthClasses), so a build leaning on beastmaster stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    damage = 2, stamina = 4, health = 3, speed = 1,
}
