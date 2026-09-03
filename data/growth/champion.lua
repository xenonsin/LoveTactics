-- Per-level stat gains for a character growing as a champion (fighter x knight discipline).
-- Riposte-wall: the frontline bruiser -- fighter's arm on a knight's frame.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/class.lua's growthClasses), so a build leaning on champion stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    health = 5, damage = 3, defense = 2,
}
