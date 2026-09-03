-- Per-level stat gains for a character growing as a plague_knight (knight x alchemist discipline).
-- Contagion: a plated body carrying rot -- defence and a little venomous magic.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/class.lua's growthClasses), so a build leaning on plague_knight stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    health = 5, defense = 2, magicDamage = 2, magicDefense = 1,
}
