-- Per-level stat gains for a character growing as a assassin (rogue discipline).
-- Blink-execute: speed and damage, almost no bulk -- the burst archetype.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/discipline.lua's growthClasses), so a build leaning on assassin stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    speed = 2, damage = 5, stamina = 3,
}
