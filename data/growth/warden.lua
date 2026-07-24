-- Per-level stat gains for a character growing as a warden (knight x hunter discipline).
-- Lockdown: holds a zone -- a knight's endurance on a hunter's watch.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/discipline.lua's growthClasses), so a build leaning on warden stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    health = 4, defense = 2, damage = 2, stamina = 3,
}
