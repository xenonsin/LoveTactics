-- Per-level stat gains for a character growing as a warbrewer (fighter x alchemist discipline).
-- Combat draught: a brawler who drinks mid-fight -- stamina and a little brew.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/class.lua's growthClasses), so a build leaning on warbrewer stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    health = 3, damage = 3, stamina = 3, magicDamage = 2,
}
